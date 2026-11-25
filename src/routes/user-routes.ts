import { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { hashPassword, newPasswordSchema, verifyPassword } from "../lib/password.js";
import { serializeUser } from "../lib/serialize.js";
import { signSessionToken } from "../lib/session-token.js";
import { authenticate } from "../middlewares/authenticate.js";
import { authorizeSelf } from "../middlewares/authorize-self.js";
import { rateLimit } from "../middlewares/rate-limit.js";
import { refreshStreaks, withUserLock } from "../services/streak-service.js";
import { MIN_DAILY_GOAL, calculateWaterGoal } from "../utils/calculate-water-goal.js";
import { checkAndUnlockAchievements } from "../utils/check-achieviments.js";
import { dayRange } from "../utils/date-range.js";

const MAX_DAILY_GOAL = 10_000;
const HIGH_GOAL_WARNING =
  "Your custom daily goal exceeds 4000ml. Please consult with a healthcare professional.";

const nameSchema = z
  .string()
  .trim()
  .min(2, "Name must be at least 2 characters long")
  .max(80, "Name must be at most 80 characters long");

const weightSchema = z.number().positive().max(500);

// A meta nunca fica abaixo de 2000ml, no cadastro ou depois
const goalSchema = () =>
  z
    .number()
    .int("Daily goal must be a whole number")
    .min(MIN_DAILY_GOAL, `Custom daily goal must be at least ${MIN_DAILY_GOAL}ml`)
    .max(MAX_DAILY_GOAL, `Custom daily goal must be at most ${MAX_DAILY_GOAL}ml`);

export async function userRoutes(app: FastifyInstance) {
  const selfOnly = { onRequest: [authenticate, authorizeSelf] };

  app.post("/users", { onRequest: [rateLimit(10)] }, async (request, reply) => {
    const registerBodySchema = z.object({
      name: nameSchema,
      username: z
        .string()
        .trim()
        .toLowerCase()
        .min(3, "Username must be at least 3 characters long")
        .max(70, "Username must be at most 70 characters long")
        // sem "@": um username nunca pode se passar pelo e-mail de outra pessoa no login
        .regex(/^[a-z0-9._-]+$/, "Username may only contain letters, numbers, '.', '_' and '-'"),
      email: z.string().trim().toLowerCase().pipe(z.email("Invalid email address")),
      password: newPasswordSchema,
      weightKg: weightSchema.optional(),
      avatarUrl: z.url({ protocol: /^https?$/ }).optional(),
      customDailyGoal: goalSchema().optional(),
    });

    const body = registerBodySchema.parse(request.body);

    const userWithSameEmail = await prisma.user.findUnique({
      where: {
        email: body.email,
      },
    });

    if (userWithSameEmail) {
      return reply.status(400).send({ error: "Email already exists" });
    }

    const userWithSameUsername = await prisma.user.findUnique({
      where: {
        username: body.username,
      },
    });

    if (userWithSameUsername) {
      return reply.status(400).send({ error: "Username already exists" });
    }

    let finalGoal: number;
    let goalWarning: string | undefined;

    if (body.customDailyGoal) {
      finalGoal = body.customDailyGoal;
      if (finalGoal > 4000) goalWarning = HIGH_GOAL_WARNING;
    } else {
      const calculation = calculateWaterGoal(body.weightKg);
      finalGoal = calculation.dailyGoal;
      goalWarning = calculation.warning;
    }

    const user = await prisma.user.create({
      data: {
        name: body.name,
        username: body.username,
        email: body.email,
        passwordHash: await hashPassword(body.password),
        weight: body.weightKg,
        avatarUrl: body.avatarUrl,
        dailyGoal: finalGoal,
      },
    });

    // Quem acabou de se cadastrar já sai autenticado
    const token = await signSessionToken(reply, user.id);

    return reply.status(201).send({
      token,
      user: serializeUser(user),
      warning: goalWarning,
    });
  });

  // Perfil do utilizador autenticado (o ID vem do token)
  app.get("/users/me", { onRequest: [authenticate] }, async (request, reply) => {
    const user = await prisma.user.findUnique({
      where: { id: request.user.sub },
    });

    if (!user) {
      return reply.status(404).send({ error: "Utilizador não encontrado." });
    }

    return reply.status(200).send({ user: serializeUser(user) });
  });

  // Editar perfil e meta diária
  app.patch("/users/:userId", selfOnly, async (request, reply) => {
    const bodySchema = z
      .object({
        name: nameSchema.optional(),
        weight: weightSchema.optional(),
        dailyGoal: goalSchema().optional(),
      })
      .refine((body) => Object.values(body).some((value) => value !== undefined), {
        message: "Envie ao menos um campo para alterar.",
      });

    const body = bodySchema.parse(request.body);
    const userId = request.user.sub;

    const user = await withUserLock(userId, async (tx) => {
      const current = await tx.user.findUnique({ where: { id: userId } });
      if (!current) return null;

      const updated = await tx.user.update({ where: { id: userId }, data: body });
      if (body.dailyGoal === undefined) return updated;

      // A nova meta vale a partir de hoje; os dias anteriores mantêm a meta da época
      await tx.waterLog.updateMany({
        where: { userId, createdAt: dayRange(new Date()) },
        data: { dailyGoal: body.dailyGoal },
      });
      const streaks = await refreshStreaks(tx, userId, body.dailyGoal);
      return { ...updated, ...streaks };
    });

    if (!user) {
      return reply.status(404).send({ error: "Utilizador não encontrado." });
    }

    // Baixar a meta pode completar uma sequência
    const newAchievements =
      body.dailyGoal === undefined ? [] : await checkAndUnlockAchievements(userId);

    return reply.status(200).send({
      user: serializeUser(user),
      newAchievements,
      warning: body.dailyGoal && body.dailyGoal > 4000 ? HIGH_GOAL_WARNING : undefined,
    });
  });

  // Alterar a senha estando logado
  app.patch(
    "/users/:userId/password",
    { onRequest: [rateLimit(10), authenticate, authorizeSelf] },
    async (request, reply) => {
      const bodySchema = z.object({
        currentPassword: z.string().min(1, "Password is required"),
        newPassword: newPasswordSchema,
      });

      const { currentPassword, newPassword } = bodySchema.parse(request.body);
      const userId = request.user.sub;

      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        return reply.status(404).send({ error: "Utilizador não encontrado." });
      }

      if (!(await verifyPassword(currentPassword, user.passwordHash))) {
        return reply.status(400).send({ error: "Invalid credentials" });
      }

      await prisma.user.update({
        where: { id: userId },
        data: { passwordHash: await hashPassword(newPassword) },
      });

      return reply.status(204).send();
    },
  );

  // Excluir a conta (registros, participações e conquistas saem em cascata)
  app.delete("/users/:userId", selfOnly, async (request, reply) => {
    const userId = request.user.sub;

    const deleted = await prisma.$transaction(async (tx) => {
      // Ligas criadas por quem sai passam ao membro mais antigo, em vez de sumirem para todos.
      // Ligas sem mais ninguém são apagadas pela própria cascata.
      const ownedLeagues = await tx.league.findMany({
        where: { ownerId: userId },
        select: {
          id: true,
          members: {
            where: { userId: { not: userId } },
            orderBy: { joinedAt: "asc" },
            take: 1,
            select: { userId: true },
          },
        },
      });

      for (const league of ownedLeagues) {
        const heir = league.members[0];
        if (heir) {
          await tx.league.update({ where: { id: league.id }, data: { ownerId: heir.userId } });
        }
      }

      const { count } = await tx.user.deleteMany({ where: { id: userId } });
      return count > 0;
    });

    if (!deleted) {
      return reply.status(404).send({ error: "Utilizador não encontrado." });
    }

    return reply.status(204).send();
  });
}
