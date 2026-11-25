import { FastifyInstance, FastifyReply } from "fastify";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { isUniqueViolation } from "../lib/prisma-errors.js";
import { authenticate } from "../middlewares/authenticate.js";
import { authorizeSelf } from "../middlewares/authorize-self.js";
import { rateLimit } from "../middlewares/rate-limit.js";

// Função para gerar um código aleatório de convite para a liga
function generateLeagueCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let randomCode = "";
  for (let i = 0; i < 4; i++) {
    randomCode += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return `GOTA-${randomCode}`;
}

async function generateUniqueCode(): Promise<string> {
  let code = generateLeagueCode();
  while (await prisma.league.findUnique({ where: { code } })) {
    code = generateLeagueCode();
  }
  return code;
}

// Aceita o código como a pessoa digitar: "gota-ab12", "GOTAAB12" ou só "ab12"
function normalizeCode(input: string): string {
  const compact = input.toUpperCase().replace(/[\s-]/g, "");
  const match = /^(?:GOTA)?([A-Z0-9]{4})$/.exec(compact);
  return match ? `GOTA-${match[1]}` : input.toUpperCase();
}

const codeSchema = z
  .string()
  .trim()
  .min(1, "O código da liga é obrigatório")
  .max(30)
  .transform(normalizeCode);

const nameSchema = z
  .string()
  .trim()
  .min(3, "O nome da liga deve ter pelo menos 3 caracteres")
  .max(50, "O nome da liga deve ter no máximo 50 caracteres");

const descriptionSchema = z
  .string()
  .trim()
  .max(200, "A descrição deve ter no máximo 200 caracteres");

const leagueParamsSchema = z.object({ id: z.uuid("ID da liga inválido") });

const NOT_ADMIN = { error: "Apenas o administrador da liga pode fazer isso." };

// Busca a liga e confere se quem pede é o administrador; responde o erro e devolve null se não for
async function findOwnedLeague(id: string, userId: string, reply: FastifyReply) {
  const league = await prisma.league.findUnique({ where: { id } });

  if (!league) {
    reply.status(404).send({ error: "Liga não encontrada." });
    return null;
  }
  if (league.ownerId !== userId) {
    reply.status(403).send(NOT_ADMIN);
    return null;
  }
  return league;
}

async function listLeagues(userId: string) {
  const memberships = await prisma.leagueMember.findMany({
    where: { userId },
    orderBy: { joinedAt: "desc" },
    include: {
      league: {
        include: { _count: { select: { members: true } } },
      },
    },
  });

  return memberships.map(({ league, joinedAt }) => ({
    id: league.id,
    name: league.name,
    description: league.description,
    code: league.code,
    endDate: league.endDate,
    ownerId: league.ownerId,
    isOwner: league.ownerId === userId,
    memberCount: league._count.members,
    joinedAt,
  }));
}

export async function leagueRoutes(app: FastifyInstance) {
  // Um único contador para as duas rotas que testam códigos de convite
  const limitCodeAttempts = rateLimit(20);

  // 1. Criar uma nova Liga
  app.post("/leagues", { onRequest: [authenticate] }, async (request, reply) => {
    const createLeagueBodySchema = z.object({
      name: nameSchema,
      description: descriptionSchema.optional(),
      endDate: z.iso.datetime().optional(),
    });

    const { name, description, endDate } = createLeagueBodySchema.parse(
      request.body,
    );

    // O criador da liga é quem está autenticado
    const ownerId = request.user.sub;

    const owner = await prisma.user.findUnique({
      where: { id: ownerId },
    });

    if (!owner) {
      return reply
        .status(404)
        .send({ error: "Utilizador criador não encontrado." });
    }

    const code = await generateUniqueCode();

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
  app.post(
    "/leagues/join",
    { onRequest: [limitCodeAttempts, authenticate] },
    async (request, reply) => {
      const { code } = z.object({ code: codeSchema }).parse(request.body);
      const userId = request.user.sub;
      const alreadyMember = { error: "Já fazes parte desta liga." };

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

      if (league.endDate && league.endDate.getTime() < Date.now()) {
        return reply.status(400).send({ error: "Esta liga já terminou." });
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
        return reply.status(400).send(alreadyMember);
      }

      try {
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
      } catch (error) {
        // Toque duplo no botão: a outra requisição entrou primeiro
        if (isUniqueViolation(error)) return reply.status(400).send(alreadyMember);
        throw error;
      }
    },
  );

  // Prévia da liga antes de entrar
  app.get(
    "/leagues/code/:code",
    { onRequest: [limitCodeAttempts, authenticate] },
    async (request, reply) => {
      const { code } = z.object({ code: codeSchema }).parse(request.params);

      const league = await prisma.league.findUnique({
        where: { code },
        select: {
          id: true,
          name: true,
          code: true,
          owner: { select: { name: true } },
          _count: { select: { members: true } },
        },
      });

      if (!league) {
        return reply.status(404).send({ error: "Liga não encontrada com este código." });
      }

      return reply.status(200).send({
        league: {
          id: league.id,
          name: league.name,
          code: league.code,
          memberCount: league._count.members,
          ownerName: league.owner.name,
        },
      });
    },
  );

  // 3. Obter o Ranking (Leaderboard) da Liga
  app.get("/leagues/:id/leaderboard", { onRequest: [authenticate] }, async (request, reply) => {
    const { id } = leagueParamsSchema.parse(request.params);

    const league = await prisma.league.findUnique({
      where: { id },
      include: {
        members: {
          orderBy: { joinedAt: "asc" },
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

    // O ranking (e o código de convite) é só para quem participa
    if (!league.members.some((member) => member.user.id === request.user.sub)) {
      return reply.status(403).send({ error: "Acesso negado." });
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
        ownerId: league.ownerId,
      },
      leaderboard,
    });
  });

  // 4. Listar as ligas em que o utilizador autenticado participa
  app.get("/leagues", { onRequest: [authenticate] }, async (request, reply) => {
    return reply.status(200).send({ leagues: await listLeagues(request.user.sub) });
  });

  app.get(
    "/users/:userId/leagues",
    { onRequest: [authenticate, authorizeSelf] },
    async (request, reply) => {
      return reply.status(200).send({ leagues: await listLeagues(request.user.sub) });
    },
  );

  // 5. Renomear ou editar a descrição (administrador)
  app.patch("/leagues/:id", { onRequest: [authenticate] }, async (request, reply) => {
    const bodySchema = z
      .object({ name: nameSchema.optional(), description: descriptionSchema.optional() })
      .refine((body) => body.name !== undefined || body.description !== undefined, {
        message: "Envie ao menos um campo para alterar.",
      });

    const { id } = leagueParamsSchema.parse(request.params);
    const data = bodySchema.parse(request.body);

    if (!(await findOwnedLeague(id, request.user.sub, reply))) return reply;

    const league = await prisma.league.update({ where: { id }, data });
    return reply.status(200).send({ league });
  });

  // 6. Trocar o código de convite (administrador); o anterior deixa de funcionar
  app.post("/leagues/:id/code", { onRequest: [authenticate] }, async (request, reply) => {
    const { id } = leagueParamsSchema.parse(request.params);

    if (!(await findOwnedLeague(id, request.user.sub, reply))) return reply;

    const code = await generateUniqueCode();
    await prisma.league.update({ where: { id }, data: { code } });
    return reply.status(200).send({ code });
  });

  // 7. Sair da liga (a própria pessoa) ou remover um membro (administrador)
  app.delete(
    "/leagues/:id/members/:userId",
    { onRequest: [authenticate] },
    async (request, reply) => {
      const paramsSchema = leagueParamsSchema.extend({
        userId: z.uuid("ID de utilizador inválido"),
      });
      const { id, userId } = paramsSchema.parse(request.params);
      const requesterId = request.user.sub;

      const league = await prisma.league.findUnique({ where: { id } });
      if (!league) {
        return reply.status(404).send({ error: "Liga não encontrada." });
      }
      if (userId !== requesterId && league.ownerId !== requesterId) {
        return reply.status(403).send(NOT_ADMIN);
      }

      const removed = await prisma.$transaction(async (tx) => {
        const { count } = await tx.leagueMember.deleteMany({ where: { leagueId: id, userId } });
        if (count === 0) return false;

        // O administrador saiu: o membro mais antigo assume; sem ninguém, a liga é apagada
        if (userId === league.ownerId) {
          const heir = await tx.leagueMember.findFirst({
            where: { leagueId: id },
            orderBy: { joinedAt: "asc" },
          });
          if (heir) {
            await tx.league.update({ where: { id }, data: { ownerId: heir.userId } });
          } else {
            await tx.league.delete({ where: { id } });
          }
        }
        return true;
      });

      if (!removed) {
        return reply.status(404).send({ error: "Essa pessoa não participa da liga." });
      }

      return reply.status(204).send();
    },
  );
}
