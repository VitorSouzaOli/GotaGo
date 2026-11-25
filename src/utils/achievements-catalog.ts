export interface AchievementStats {
  totalLogs: number;
  /** Maior sequência já alcançada: uma conquista merecida não se perde se a sequência quebrar */
  bestStreak: number;
}

// Catálogo de conquistas: usado pela regra de desbloqueio e pelo seed
export const ACHIEVEMENTS = [
  {
    code: "FIRST_DROP",
    name: "Primeira Gota",
    description: "Registaste o teu primeiro consumo de água no GotaGo!",
    isEarned: (stats: AchievementStats) => stats.totalLogs >= 1,
  },
  {
    code: "STREAK_3_DAYS",
    name: "3 Dias Hidratado",
    description: "Atingiste a meta diária por 3 dias consecutivos!",
    isEarned: (stats: AchievementStats) => stats.bestStreak >= 3,
  },
  {
    code: "STREAK_7_DAYS",
    name: "Semana Perfeita",
    description: "Atingiste a meta diária por 7 dias consecutivos!",
    isEarned: (stats: AchievementStats) => stats.bestStreak >= 7,
  },
  {
    code: "STREAK_30_DAYS",
    name: "Mestre da Hidratação",
    description: "Mantiveste a tua meta por 30 dias seguidos!",
    isEarned: (stats: AchievementStats) => stats.bestStreak >= 30,
  },
];
