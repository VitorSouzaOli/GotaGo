import { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { checkAndUnlockAchievements } from "../utils/check-achieviments.js";

export async function waterLogRoutes(app: FastifyInstance) {
  app.post("/water-logs", async (request, reply) => {
    const createWaterLogBodySchema = z.object({
      userId: z.uuid("ID de utilizador inválido"),
      amount: z
        .number()
        .positive("A quantidade consumida deve ser maior que 0"),
    });

    const { userId, amount } = createWaterLogBodySchema.parse(request.body);

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
}
