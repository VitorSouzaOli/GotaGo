import { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";

export async function achievementRoutes(app: FastifyInstance) {
  // Obter todas as conquistas do utilizador (desbloqueadas e pendentes)
  app.get("/users/:userId/achievements", async (request, reply) => {
    const getAchievementsParamsSchema = z.object({
      userId: z.uuid("ID de utilizador inválido"),
    });

    const { userId } = getAchievementsParamsSchema.parse(request.params);

    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      return reply.status(404).send({ error: "Utilizador não encontrado." });
    }

    const allAchievements = await prisma.achievement.findMany();
    const userAchievements = await prisma.userAchievement.findMany({
      where: { userId },
      select: { achievementId: true, unlockedAt: true },
    });

    const unlockedMap = new Map(
      userAchievements.map((ua) => [ua.achievementId, ua.unlockedAt]),
    );

    const result = allAchievements.map((achievement) => ({
      id: achievement.id,
      code: achievement.code,
      name: achievement.name,
      description: achievement.description,
      isUnlocked: unlockedMap.has(achievement.id),
      unlockedAt: unlockedMap.get(achievement.id) || null,
    }));

    return reply.status(200).send({ achievements: result });
  });
}
