import { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { hashPassword, verifyPassword } from "../lib/password.js";
import { serializeUser } from "../lib/serialize.js";
import { signSessionToken } from "../lib/session-token.js";
import { rateLimit } from "../middlewares/rate-limit.js";

export async function sessionRoutes(app: FastifyInstance) {
  // Comparado quando o utilizador não existe, para o tempo de resposta não revelar quem tem conta
  const dummyHash = await hashPassword("utilizador-inexistente");

  app.post("/sessions", { onRequest: [rateLimit(10)] }, async (request, reply) => {
    const sessionBodySchema = z.object({
      login: z.string().trim().min(1, "E-mail or username is required"),
      password: z.string().min(1, "Password is required"),
    });

    const { login, password } = sessionBodySchema.parse(request.body);
    const normalizedLogin = login.toLowerCase();

    // Permite login por e-mail ou por username, sem diferenciar maiúsculas
    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { email: normalizedLogin },
          { username: normalizedLogin },
          // o e-mail exato cobre contas antigas que continuaram gravadas com maiúsculas
          ...(normalizedLogin !== login ? [{ email: login }] : []),
        ],
      },
    });

    // Compara a senha enviada com o hash salvo no banco
    const doesPasswordMatch = await verifyPassword(password, user?.passwordHash ?? dummyHash);

    if (!user || !doesPasswordMatch) {
      return reply.status(400).send({ error: "Invalid credentials" });
    }

    const token = await signSessionToken(reply, user.id);

    return reply.status(200).send({ token, user: serializeUser(user) });
  });
}
