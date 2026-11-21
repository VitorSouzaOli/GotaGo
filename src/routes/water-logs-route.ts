import { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { authenticate } from "../middlewares/authenticate.js";
import { startOfDay, toDateKey } from "../utils/date-range.js";
import { checkAndUnlockAchievements } from "../utils/check-achieviments.js";

export async function waterLogRoutes(app: FastifyInstance) {
  app.post("/water-logs", { onRequest: [authenticate] }, async (request, reply) => {
    const createWaterLogBodySchema = z.object({
      amount: z
        .number()
        .positive("A quantidade consumida deve ser maior que 0"),
    });

    const { amount } = createWaterLogBodySchema.parse(request.body);

    // O usuário vem do token, não do corpo: ninguém registra água por outra pessoa
    const userId = request.user.sub;

    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      return reply.status(404).send({ error: "Utilizador não encontrado." });
    }

    // 1. Gravar o novo consumo de água
    const waterLog = await prisma.waterLog.create({
      data: {
        userId,
        amount,
      },
    });

    // 2. Calcular o acumulado de hoje (entre as 00:00 e as 23:59)
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const todayLogs = await prisma.waterLog.aggregate({
      _sum: {
        amount: true,
      },
      where: {
        userId,
        createdAt: {
          gte: startOfDay,
          lte: endOfDay,
        },
      },
    });

    const totalToday = todayLogs._sum.amount || 0;

    // 3. Alerta de segurança de consumo excessivo (> 4000ml no mesmo dia)
    let warning: string | undefined;
    if (totalToday > 4000) {
      warning =
        "Atenção: O teu consumo total de hoje ultrapassou os 4000ml. Beber água em excesso num curto período de tempo pode causar sobrecarga renal ou hiponatremia.";
    }

    // 4. Lógica de Streak: verificar se acabou de bater a meta no registo atual
    let streakUpdated = false;
    const goalReached = totalToday >= user.dailyGoal;
    const previousTotal = totalToday - amount;

    // Se o total anterior era menor que a meta e o novo total atingiu a meta: incrementa a streak
    if (goalReached && previousTotal < user.dailyGoal) {
      const newCurrentStreak = user.currentStreak + 1;
      const newMaxStreak = Math.max(newCurrentStreak, user.maxStreak);

      await prisma.user.update({
        where: { id: userId },
        data: {
          currentStreak: newCurrentStreak,
          maxStreak: newMaxStreak,
        },
      });

      streakUpdated = true;
    }

    // 5. Verificar e desbloquear conquistas
    const newAchievements = await checkAndUnlockAchievements(userId);

    return reply.status(201).send({
      waterLog,
      totalToday,
      dailyGoal: user.dailyGoal,
      goalReached,
      streakUpdated,
      newAchievements, // Lista de novas conquistas desbloqueadas nesta requisição
      warning,
    });
  });

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

    const start = startOfDay(new Date());
    const end = new Date(start);
    end.setDate(end.getDate() + 1);

    const logs = await prisma.waterLog.findMany({
      where: { userId, createdAt: { gte: start, lt: end } },
      orderBy: { createdAt: "desc" },
      select: { id: true, amount: true, createdAt: true },
    });

    const totalToday = logs.reduce((sum, log) => sum + log.amount, 0);

    return reply.status(200).send({
      date: toDateKey(start),
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
    const historyQuerySchema = z.object({
      days: z.coerce.number().int().min(1).max(90).default(7),
    });

    const { days } = historyQuerySchema.parse(request.query);
    const userId = request.user.sub;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { dailyGoal: true },
    });

    if (!user) {
      return reply.status(404).send({ error: "Utilizador não encontrado." });
    }

    const firstDay = startOfDay(new Date());
    firstDay.setDate(firstDay.getDate() - (days - 1));

    const logs = await prisma.waterLog.findMany({
      where: { userId, createdAt: { gte: firstDay } },
      select: { amount: true, createdAt: true },
    });

    const totalsByDay = new Map<string, number>();
    for (const log of logs) {
      const key = toDateKey(log.createdAt);
      totalsByDay.set(key, (totalsByDay.get(key) ?? 0) + log.amount);
    }

    // Inclui os dias sem nenhum registro (total 0) para o app montar o gráfico completo
    const history = [];
    for (let i = 0; i < days; i++) {
      const day = new Date(firstDay);
      day.setDate(firstDay.getDate() + i);
      const key = toDateKey(day);
      const total = totalsByDay.get(key) ?? 0;

      history.push({ date: key, total, goalReached: total >= user.dailyGoal });
    }

    return reply.status(200).send({
      dailyGoal: user.dailyGoal,
      history: history.reverse(),
    });
  });
}
