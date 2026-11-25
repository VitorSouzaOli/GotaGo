import { FastifyReply, FastifyRequest } from "fastify";

// "Segurança da porta": roda antes da rota e só deixa passar quem tem um token válido.
// Se passar, o ID do usuário fica disponível em request.user.sub.
export async function authenticate(
  request: FastifyRequest,
  reply: FastifyReply,
) {
  try {
    await request.jwtVerify();
  } catch {
    return reply.status(401).send({ error: "Token inválido ou ausente." });
  }
}
