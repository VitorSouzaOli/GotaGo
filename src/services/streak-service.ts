import { Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { calculateStreaks } from "../utils/streak.js";

// Executa `action` numa transação que trava a linha do utilizador: dois registros
// simultâneos são processados um de cada vez e o streak nunca é calculado com dados velhos.
export function withUserLock<T>(
  userId: string,
  action: (tx: Prisma.TransactionClient) => Promise<T>,
) {
  return prisma.$transaction(async (tx) => {
    await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${userId} FOR UPDATE`;
    return action(tx);
  });
}

// Recalcula e grava o streak (usado ao criar, editar, excluir registros e mudar a meta)
export async function refreshStreaks(
  tx: Prisma.TransactionClient,
  userId: string,
  dailyGoal: number,
) {
  const logs = await tx.waterLog.findMany({
    where: { userId },
    select: { amount: true, createdAt: true, dailyGoal: true },
  });

  const streaks = calculateStreaks(logs, dailyGoal);
  await tx.user.update({ where: { id: userId }, data: streaks });
  return streaks;
}
