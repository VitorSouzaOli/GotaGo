import { FastifyInstance } from "fastify";
import { hash } from "bcryptjs";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { calculateWaterGoal } from "../utils/calculate-water-goal.js";

export async function userRoutes(app: FastifyInstance) {
  app.post("/users", async (request, reply) => {
    const registerBodySchema = z.object({
      name: z.string().min(2, "Name must be at least 2 characters long"),
      username: z
        .string()
        .min(3, "Username must be at least 3 characters long")
        .toLowerCase(),
      email: z.email("Invalid email address"),
      password: z
        .string()
        .min(6, "Password must be at least 6 characters long"),
      weightKg: z.number().positive().optional(),
      avatarUrl: z.url().optional(),
      customDailyGoal: z
        .number()
        .min(2000, "Custom daily goal must be at least 2000ml")
        .optional(),
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

    let finalGoal = 2000;
    let goalWarning: string | undefined;

    if (body.customDailyGoal) {
      finalGoal = body.customDailyGoal;
      if (finalGoal > 4000) {
        goalWarning =
          "Your custom daily goal exceeds 4000ml. Please consult with a healthcare professional.";
      }
    } else {
      const calculation = calculateWaterGoal(body.weightKg);
      finalGoal = calculation.dailyGoal;
      goalWarning = calculation.warning;
    }

    const passwordHash = await hash(body.password, 6);

    const user = await prisma.user.create({
      data: {
        name: body.name,
        username: body.username,
        email: body.email,
        passwordHash,
        weight: body.weightKg,
        avatarUrl: body.avatarUrl,
        dailyGoal: finalGoal,
      },
    });

    return reply.status(201).send({
      user: {
        id: user.id,
        name: user.name,
        username: user.username,
        email: user.email,
        avatarUrl: user.avatarUrl,
        weight: user.weight,
        dailyGoal: user.dailyGoal,
        currentStreak: user.currentStreak,
        maxStreak: user.maxStreak,
      },
      warning: goalWarning,
    });
  });
}
