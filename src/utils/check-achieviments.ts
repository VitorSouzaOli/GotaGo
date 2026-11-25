import { prisma } from "../lib/prisma.js";
import { ACHIEVEMENTS } from "./achievements-catalog.js";

// Desbloqueia o que o utilizador acabou de conquistar e devolve os nomes das novas conquistas
export async function checkAndUnlockAchievements(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      maxStreak: true,
      // só a contagem: não é preciso carregar todos os registros de água
      _count: { select: { waterLogs: true } },
      achievements: { select: { achievement: { select: { code: true } } } },
    },
  });

  if (!user) return [];

  const unlockedCodes = new Set(user.achievements.map((ua) => ua.achievement.code));
  const stats = { totalLogs: user._count.waterLogs, bestStreak: user.maxStreak };
  const newlyUnlocked: string[] = [];

  for (const { code, name, description, isEarned } of ACHIEVEMENTS) {
    if (unlockedCodes.has(code) || !isEarned(stats)) continue;

    // Garante que a conquista existe na tabela principal de Achievements
    const achievement = await prisma.achievement.upsert({
      where: { code },
      update: {},
      create: { code, name, description },
    });

    // skipDuplicates: duas requisições simultâneas não geram erro nem aviso repetido
    const { count } = await prisma.userAchievement.createMany({
      data: [{ userId, achievementId: achievement.id }],
      skipDuplicates: true,
    });

    if (count > 0) newlyUnlocked.push(achievement.name);
  }

  return newlyUnlocked;
}
