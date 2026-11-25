import { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { authenticate } from "../middlewares/authenticate.js";
import { authorizeSelf } from "../middlewares/authorize-self.js";
import { refreshStreaks, withUserLock } from "../services/streak-service.js";
import { addDays, dayRange, startOfDay, toDateKey } from "../utils/date-range.js";
import { checkAndUnlockAchievements } from "../utils/check-achieviments.js";
import { summarizeByDay } from "../utils/streak.js";

const MAX_AMOUNT = 5000;
// Tolerância para o relógio do celular um pouco adiantado
const CLOCK_SKEW_MS = 5 * 60_000;

const amountSchema = z
  .number()
  .int("A quantidade deve ser um número inteiro de ml")
  .positive("A quantidade consumida deve ser maior que 0")
  .max(MAX_AMOUNT, `Registre no máximo ${MAX_AMOUNT} ml por vez`);

const logParamsSchema = z.object({ id: z.uuid("ID do registro inválido") });

const daysSchema = (fallback: number) =>
  z.object({ days: z.coerce.number().int().min(1).max(90).default(fallback) });

export async function waterLogRoutes(app: FastifyInstance) {
  app.post("/water-logs", { onRequest: [authenticate] }, async (request, reply) => {
    const createWaterLogBodySchema = z.object({ amount: amountSchema });

    const { amount } = createWaterLogBodySchema.parse(request.body);

    // O usuário vem do token, não do corpo: ninguém registra água por outra pessoa
    const userId = request.user.sub;

    const result = await withUserLock(userId, async (tx) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) return null;

      // 1. Gravar o consumo, junto com a meta que valia neste momento
      const waterLog = await tx.waterLog.create({
        data: { userId, amount, dailyGoal: user.dailyGoal },
      });

      // 2. Acumulado de hoje
      const today = await tx.waterLog.aggregate({
        _sum: { amount: true },
        where: { userId, createdAt: dayRange(new Date()) },
      });
      const totalToday = today._sum.amount ?? 0;

      // 3. Recalcular o streak
      const streaks = await refreshStreaks(tx, userId, user.dailyGoal);

      return { waterLog, totalToday, dailyGoal: user.dailyGoal, ...streaks };
    });

    if (!result) {
      return reply.status(404).send({ error: "Utilizador não encontrado." });
    }

    const { totalToday, dailyGoal } = result;
    const goalReached = totalToday >= dailyGoal;

    // 4. Alerta de segurança de consumo excessivo (> 4000ml no mesmo dia)
    let warning: string | undefined;
    if (totalToday > 4000) {
      warning =
        "Atenção: O teu consumo total de hoje ultrapassou os 4000ml. Beber água em excesso num curto período de tempo pode causar sobrecarga renal ou hiponatremia.";
    }

    // 5. Verificar e desbloquear conquistas
    const newAchievements = await checkAndUnlockAchievements(userId);

    return reply.status(201).send({
      ...result,
      goalReached,
      // true só no registro que fez o dia cruzar a meta
      streakUpdated: goalReached && totalToday - amount < dailyGoal,
      newAchievements, // Lista de novas conquistas desbloqueadas nesta requisição
      warning,
    });
  });

  // Corrigir quantidade ou horário de um registro
  app.patch("/water-logs/:id", { onRequest: [authenticate] }, async (request, reply) => {
    const bodySchema = z
      .object({
        amount: amountSchema.optional(),
        createdAt: z.iso.datetime({ offset: true }).optional(),
      })
      .refine((body) => body.amount !== undefined || body.createdAt !== undefined, {
        message: "Envie ao menos um campo para alterar.",
      });

    const { id } = logParamsSchema.parse(request.params);
    const body = bodySchema.parse(request.body);
    const userId = request.user.sub;
    const createdAt = body.createdAt ? new Date(body.createdAt) : undefined;

    if (createdAt && createdAt.getTime() > Date.now() + CLOCK_SKEW_MS) {
      return reply.status(400).send({ error: "O horário não pode estar no futuro." });
    }

    const result = await withUserLock(userId, async (tx) => {
      // filtrar por userId: ninguém altera (nem descobre) o registro de outra pessoa
      const log = await tx.waterLog.findFirst({ where: { id, userId } });
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!log || !user) return "not-found" as const;

      // Mudar de dia permitiria preencher dias perdidos e inflar o streak
      if (createdAt && toDateKey(createdAt) !== toDateKey(log.createdAt)) {
        return "other-day" as const;
      }

      const waterLog = await tx.waterLog.update({
        where: { id },
        data: { amount: body.amount, createdAt },
        select: { id: true, amount: true, createdAt: true },
      });
      const streaks = await refreshStreaks(tx, userId, user.dailyGoal);

      return { waterLog, ...streaks };
    });

    if (result === "not-found") {
      return reply.status(404).send({ error: "Registro não encontrado." });
    }
    if (result === "other-day") {
      return reply.status(400).send({ error: "O horário precisa continuar no mesmo dia." });
    }

    // A correção pode completar uma sequência
    const newAchievements = await checkAndUnlockAchievements(userId);

    return reply.status(200).send({ ...result, newAchievements });
  });

  // Excluir um registro
  app.delete("/water-logs/:id", { onRequest: [authenticate] }, async (request, reply) => {
    const { id } = logParamsSchema.parse(request.params);
    const userId = request.user.sub;

    const deleted = await withUserLock(userId, async (tx) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) return false;

      const { count } = await tx.waterLog.deleteMany({ where: { id, userId } });
      if (count === 0) return false;

      await refreshStreaks(tx, userId, user.dailyGoal);
      return true;
    });

    if (!deleted) {
      return reply.status(404).send({ error: "Registro não encontrado." });
    }

    return reply.status(204).send();
  });

  // Lista os registros dos últimos N dias (usada pelo app na Home e no Histórico)
  app.get(
    "/users/:userId/water-logs",
    { onRequest: [authenticate, authorizeSelf] },
    async (request, reply) => {
      const { days } = daysSchema(30).parse(request.query);
      const firstDay = addDays(startOfDay(new Date()), -(days - 1));

      const waterLogs = await prisma.waterLog.findMany({
        where: { userId: request.user.sub, createdAt: { gte: firstDay } },
        orderBy: { createdAt: "desc" },
        select: { id: true, amount: true, createdAt: true },
      });

      return reply.status(200).send({ waterLogs });
    },
  );

  // Consumo de hoje: total, meta, streak e a lista de registros do dia (mais recente primeiro)
  app.get("/water-logs/today", { onRequest: [authenticate] }, async (request, reply) => {
    const userId = request.user.sub;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { dailyGoal: true, currentStreak: true, maxStreak: true },
    });

    if (!user) {
      return reply.status(404).send({ error: "Utilizador não encontrado." });
    }

    const now = new Date();
    const logs = await prisma.waterLog.findMany({
      where: { userId, createdAt: dayRange(now) },
      orderBy: { createdAt: "desc" },
      select: { id: true, amount: true, createdAt: true },
    });

    const totalToday = logs.reduce((sum, log) => sum + log.amount, 0);

    return reply.status(200).send({
      date: toDateKey(now),
      totalToday,
      dailyGoal: user.dailyGoal,
      goalReached: totalToday >= user.dailyGoal,
      currentStreak: user.currentStreak,
      maxStreak: user.maxStreak,
      logs,
    });
  });

  // Histórico de consumo: total por dia dos últimos N dias (padrão 7, máximo 90), mais recente primeiro
  app.get("/water-logs/history", { onRequest: [authenticate] }, async (request, reply) => {
    const { days } = daysSchema(7).parse(request.query);
    const userId = request.user.sub;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { dailyGoal: true },
    });

    if (!user) {
      return reply.status(404).send({ error: "Utilizador não encontrado." });
    }

    const firstDay = addDays(startOfDay(new Date()), -(days - 1));

    const logs = await prisma.waterLog.findMany({
      where: { userId, createdAt: { gte: firstDay } },
      select: { amount: true, createdAt: true, dailyGoal: true },
    });

    const summaries = summarizeByDay(logs, user.dailyGoal);

    // Inclui os dias sem nenhum registro (total 0) para o app montar o gráfico completo
    const history = Array.from({ length: days }, (_, i) => {
      const date = toDateKey(addDays(firstDay, days - 1 - i));
      const day = summaries.get(date);
      return { date, total: day?.total ?? 0, goalReached: day?.goalReached ?? false };
    });

    return reply.status(200).send({ dailyGoal: user.dailyGoal, history });
  });
}
