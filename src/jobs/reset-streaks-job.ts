import { FastifyBaseLogger } from "fastify";
import { prisma } from "../lib/prisma.js";

// Zera o streak de quem NÃO bateu a meta ontem.
// Se a pessoa já bateu a meta hoje, o streak recomeça em 1 (hoje é o primeiro dia da nova sequência).
// Rodar várias vezes no mesmo dia dá sempre o mesmo resultado.
export async function resetBrokenStreaks() {
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  const startOfYesterday = new Date(startOfToday);
  startOfYesterday.setDate(startOfYesterday.getDate() - 1);

  // Só importa quem tem uma sequência ativa
  const users = await prisma.user.findMany({
    where: { currentStreak: { gt: 0 } },
    select: { id: true, dailyGoal: true, currentStreak: true },
  });

  if (users.length === 0) return 0;

  const userIds = users.map((user) => user.id);

  // Total bebido por usuário em um período (uma única consulta para todos)
  async function totalsBetween(from: Date, to?: Date) {
    const rows = await prisma.waterLog.groupBy({
      by: ["userId"],
      where: {
        userId: { in: userIds },
        createdAt: { gte: from, ...(to && { lt: to }) },
      },
      _sum: { amount: true },
    });
    return new Map(rows.map((row) => [row.userId, row._sum.amount ?? 0]));
  }

  const yesterdayTotals = await totalsBetween(startOfYesterday, startOfToday);
  const todayTotals = await totalsBetween(startOfToday);

  const brokenUsers = users.filter(
    (user) => (yesterdayTotals.get(user.id) ?? 0) < user.dailyGoal,
  );

  let updatedCount = 0;

  for (const user of brokenUsers) {
    const reachedGoalToday = (todayTotals.get(user.id) ?? 0) >= user.dailyGoal;
    const newStreak = reachedGoalToday ? 1 : 0;

    // Já está correto (ex.: rodou antes hoje): não precisa atualizar
    if (user.currentStreak === newStreak) continue;

    await prisma.user.update({
      where: { id: user.id },
      data: { currentStreak: newStreak },
    });
    updatedCount++;
  }

  return updatedCount;
}

// Roda o reset ao ligar o servidor (recupera dias em que ele ficou desligado)
// e depois todo dia, logo após a meia-noite.
export function startResetStreaksJob(log: FastifyBaseLogger) {
  const run = async () => {
    try {
      const total = await resetBrokenStreaks();
      log.info(`Reset de streaks concluído: ${total} usuário(s) afetado(s).`);
    } catch (error) {
      log.error(error, "Falha ao resetar streaks.");
    }
  };

  const scheduleNextRun = () => {
    const nextRun = new Date();
    nextRun.setHours(24, 0, 5, 0); // 00:00:05 de amanhã

    setTimeout(async () => {
      await run();
      scheduleNextRun();
    }, nextRun.getTime() - Date.now());
  };

  run();
  scheduleNextRun();
}
