import { FastifyInstance } from "fastify";
import { compare } from "bcryptjs";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";

export async function sessionRoutes(app: FastifyInstance) {
  app.post("/sessions", async (request, reply) => {
    const sessionBodySchema = z.object({
      login: z.string().min(1, "E-mail or username is required"),
      password: z.string().min(1, "Password is required"),
    });

    const { login, password } = sessionBodySchema.parse(request.body);

    // Permite login por e-mail ou por username
    const user = await prisma.user.findFirst({
      where: {
        OR: [{ email: login }, { username: login.toLowerCase() }],
      },
    });

    if (!user) {
      return reply.status(400).send({ error: "Invalid credentials" });
    }

    // Compara a senha enviada com o hash salvo no banco
    const doesPasswordMatch = await compare(password, user.passwordHash);

    if (!doesPasswordMatch) {
      return reply.status(400).send({ error: "Invalid credentials" });
    }

    // Gera o token: "sub" guarda o ID do usuário e ele expira em 7 dias
    const token = await reply.jwtSign({ sub: user.id }, { expiresIn: "7d" });

    return reply.status(200).send({
      token,
      user: {
        id: user.id,
        name: user.name,
        username: user.username,
        email: user.email,
        avatarUrl: user.avatarUrl,
        weight: user.weight,
        dailyGoal: user.dailyGoal,
        currentStreak: user.currentStreak,
        maxStreak: user.maxStreak,
      },
    });
  });
}
