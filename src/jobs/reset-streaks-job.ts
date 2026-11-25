import { FastifyBaseLogger } from "fastify";
import { prisma } from "../lib/prisma.js";
import { addDays, startOfDay, toDateKey } from "../utils/date-range.js";
import { LogForStreak, summarizeByDay } from "../utils/streak.js";

// Zera o streak de quem NÃO bateu a meta ontem.
// Se a pessoa já bateu a meta hoje, o streak recomeça em 1 (hoje é o primeiro dia da nova sequência).
// Rodar várias vezes no mesmo dia dá sempre o mesmo resultado.
export async function resetBrokenStreaks(now = new Date()) {
  const today = startOfDay(now);
  const yesterday = addDays(today, -1);

  // Só importa quem tem uma sequência ativa
  const users = await prisma.user.findMany({
    where: { currentStreak: { gt: 0 } },
    select: { id: true, dailyGoal: true, currentStreak: true },
  });

  if (users.length === 0) return 0;

  // Uma única consulta com os registros de ontem e de hoje de todos eles
  const logs = await prisma.waterLog.findMany({
    where: { userId: { in: users.map((user) => user.id) }, createdAt: { gte: yesterday } },
    select: { userId: true, amount: true, createdAt: true, dailyGoal: true },
  });

  const logsByUser = new Map<string, LogForStreak[]>();
  for (const log of logs) {
    const list = logsByUser.get(log.userId);
    if (list) list.push(log);
    else logsByUser.set(log.userId, [log]);
  }

  // Agrupa por novo valor para atualizar em no máximo duas consultas
  const toUpdate = new Map<number, string[]>([
    [0, []],
    [1, []],
  ]);

  for (const user of users) {
    const days = summarizeByDay(logsByUser.get(user.id) ?? [], user.dailyGoal);
    if (days.get(toDateKey(yesterday))?.goalReached) continue;

    const newStreak = days.get(toDateKey(today))?.goalReached ? 1 : 0;
    // Já está correto (ex.: rodou antes hoje): não precisa atualizar
    if (user.currentStreak !== newStreak) toUpdate.get(newStreak)!.push(user.id);
  }

  let updatedCount = 0;
  for (const [currentStreak, ids] of toUpdate) {
    if (ids.length === 0) continue;
    const { count } = await prisma.user.updateMany({
      where: { id: { in: ids } },
      data: { currentStreak },
    });
    updatedCount += count;
  }

  return updatedCount;
}

// Roda o reset ao ligar o servidor (recupera dias em que ele ficou desligado)
// e depois todo dia, logo após a meia-noite. Devolve a função que cancela o agendamento.
export function startResetStreaksJob(log: FastifyBaseLogger) {
  let timer: NodeJS.Timeout | undefined;
  let stopped = false;

  const run = async () => {
    try {
      const total = await resetBrokenStreaks();
      log.info(`Reset de streaks concluído: ${total} usuário(s) afetado(s).`);
    } catch (error) {
      log.error(error, "Falha ao resetar streaks.");
    }
  };

  const scheduleNextRun = () => {
    if (stopped) return;
    const nextRun = new Date();
    nextRun.setHours(24, 0, 5, 0); // 00:00:05 de amanhã

    timer = setTimeout(async () => {
      await run();
      scheduleNextRun();
    }, nextRun.getTime() - Date.now());
  };

  run();
  scheduleNextRun();

  return () => {
    stopped = true;
    clearTimeout(timer);
  };
}
