import { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";

// Função para gerar um código aleatório de convite para a liga
function generateLeagueCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let randomCode = "";
  for (let i = 0; i < 4; i++) {
    randomCode += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return `GOTA-${randomCode}`;
}

export async function leagueRoutes(app: FastifyInstance) {
  // 1. Criar uma nova Liga
  app.post("/leagues", async (request, reply) => {
    const createLeagueBodySchema = z.object({
      name: z
        .string()
        .min(3, "O nome da liga deve ter pelo menos 3 caracteres"),
      description: z.string().optional(),
      ownerId: z.uuid("ID de utilizador inválido"),
      endDate: z.iso.datetime().optional(),
    });

    const { name, description, ownerId, endDate } =
      createLeagueBodySchema.parse(request.body);

    const owner = await prisma.user.findUnique({
      where: { id: ownerId },
    });

    if (!owner) {
      return reply
        .status(404)
        .send({ error: "Utilizador criador não encontrado." });
    }

    // Gerar um código único
    let code = generateLeagueCode();
    let isCodeUnique = false;

    while (!isCodeUnique) {
      const existingLeague = await prisma.league.findUnique({
        where: { code },
      });
      if (!existingLeague) {
        isCodeUnique = true;
      } else {
        code = generateLeagueCode();
      }
    }

    // Cria a liga e adiciona o criador como o primeiro membro
    const league = await prisma.league.create({
      data: {
        name,
        description,
        code,
        ownerId,
        endDate: endDate ? new Date(endDate) : null,
        members: {
          create: {
            userId: ownerId,
          },
        },
      },
      include: {
        members: true,
      },
    });

    return reply.status(201).send({ league });
  });

  // 2. Entrar numa Liga através do código de convite
  app.post("/leagues/join", async (request, reply) => {
    const joinLeagueBodySchema = z.object({
      userId: z.uuid("ID de utilizador inválido"),
      code: z.string().min(1, "O código da liga é obrigatório").toUpperCase(),
    });

    const { userId, code } = joinLeagueBodySchema.parse(request.body);

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return reply.status(404).send({ error: "Utilizador não encontrado." });
    }

    const league = await prisma.league.findUnique({ where: { code } });
    if (!league) {
      return reply
        .status(404)
        .send({ error: "Liga não encontrada com este código." });
    }

    // Verificar se o utilizador já faz parte da liga
    const existingMembership = await prisma.leagueMember.findUnique({
      where: {
        leagueId_userId: {
          leagueId: league.id,
          userId,
        },
      },
    });

    if (existingMembership) {
      return reply.status(400).send({ error: "Já fazes parte desta liga." });
    }

    const membership = await prisma.leagueMember.create({
      data: {
        leagueId: league.id,
        userId,
      },
    });

    return reply.status(201).send({
      message: `Entraste na liga '${league.name}' com sucesso!`,
      membership,
    });
  });

  // 3. Obter o Ranking (Leaderboard) da Liga
  app.get("/leagues/:id/leaderboard", async (request, reply) => {
    const getLeaderboardParamsSchema = z.object({
      id: z.uuid("ID da liga inválido"),
    });

    const { id } = getLeaderboardParamsSchema.parse(request.params);

    const league = await prisma.league.findUnique({
      where: { id },
      include: {
        members: {
          include: {
            user: {
              select: {
                id: true,
                name: true,
                username: true,
                avatarUrl: true,
                currentStreak: true,
                maxStreak: true,
              },
            },
          },
        },
      },
    });

    if (!league) {
      return reply.status(404).send({ error: "Liga não encontrada." });
    }

    // Ordena os membros pelo maior número de dias seguidos a bater a meta (currentStreak)
    const leaderboard = league.members
      .map((member) => member.user)
      .sort((a, b) => b.currentStreak - a.currentStreak);

    return reply.status(200).send({
      league: {
        id: league.id,
        name: league.name,
        description: league.description,
        code: league.code,
      },
      leaderboard,
    });
  });
}
