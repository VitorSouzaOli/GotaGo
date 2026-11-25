import type { User } from "@prisma/client";

// Dados do utilizador que podem sair da API (nunca o hash da senha)
export function serializeUser(user: User) {
  return {
    id: user.id,
    name: user.name,
    username: user.username,
    email: user.email,
    avatarUrl: user.avatarUrl,
    weight: user.weight,
    dailyGoal: user.dailyGoal,
    currentStreak: user.currentStreak,
    maxStreak: user.maxStreak,
  };
}
