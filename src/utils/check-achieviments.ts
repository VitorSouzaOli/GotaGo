import { prisma } from "../lib/prisma.js";

export async function checkAndUnlockAchievements(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      waterLogs: true,
      achievements: {
        include: { achievement: true },
      },
    },
  });

  if (!user) return [];

  // Obtém lista de IDs de conquistas já desbloqueadas pelo utilizador
  const unlockedCodes = new Set(
    user.achievements.map((ua) => ua.achievement.code),
  );

  const newlyUnlocked: string[] = [];

  // Definição de regras para desbloqueio
  const rules = [
    {
      code: "FIRST_DROP",
      name: "Primeira Gota",
      description: "Registaste o teu primeiro consumo de água no GotaGo!",
      condition: user.waterLogs.length >= 1,
    },
    {
      code: "STREAK_3_DAYS",
      name: "3 Dias Hidratado",
      description: "Atingiste a meta diária por 3 dias consecutivos!",
      condition: user.currentStreak >= 3,
    },
    {
      code: "STREAK_7_DAYS",
      name: "Semana Perfeita",
      description: "Atingiste a meta diária por 7 dias consecutivos!",
      condition: user.currentStreak >= 7,
    },
    {
      code: "STREAK_30_DAYS",
      name: "Mestre da Hidratação",
      description: "Mantiveste a tua meta por 30 dias seguidos!",
      condition: user.currentStreak >= 30,
    },
  ];

  for (const rule of rules) {
    if (rule.condition && !unlockedCodes.has(rule.code)) {
      // Garante que a conquista existe na tabela principal de Achievements
      const achievement = await prisma.achievement.upsert({
        where: { code: rule.code },
        update: {},
        create: {
          code: rule.code,
          name: rule.name,
          description: rule.description,
        },
      });

      // Regista o desbloqueio para o utilizador
      await prisma.userAchievement.create({
        data: {
          userId,
          achievementId: achievement.id,
        },
      });

      newlyUnlocked.push(achievement.name);
    }
  }

  return newlyUnlocked;
}
