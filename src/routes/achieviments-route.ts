import { FastifyInstance } from "fastify";
import { prisma } from "../lib/prisma.js";
import { authenticate } from "../middlewares/authenticate.js";
import { authorizeSelf } from "../middlewares/authorize-self.js";

export async function achievementRoutes(app: FastifyInstance) {
  // Obter todas as conquistas do utilizador (desbloqueadas e pendentes)
  app.get(
    "/users/:userId/achievements",
    { onRequest: [authenticate, authorizeSelf] },
    async (request, reply) => {
      const userId = request.user.sub;

      const user = await prisma.user.findUnique({
        where: { id: userId },
      });

      if (!user) {
        return reply.status(404).send({ error: "Utilizador não encontrado." });
      }

      const [allAchievements, userAchievements] = await Promise.all([
        prisma.achievement.findMany(),
        prisma.userAchievement.findMany({
          where: { userId },
          select: { achievementId: true, unlockedAt: true },
        }),
      ]);

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
    },
  );
}
