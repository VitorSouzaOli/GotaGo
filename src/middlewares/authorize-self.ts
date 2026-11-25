import { FastifyReply, FastifyRequest } from "fastify";
import { z } from "zod";

const paramsSchema = z.object({ userId: z.uuid("ID de utilizador inválido") });

// Para rotas /users/:userId/...: cada utilizador só acessa os próprios dados.
// Use depois do authenticate.
export async function authorizeSelf(request: FastifyRequest, reply: FastifyReply) {
  const { userId } = paramsSchema.parse(request.params);

  if (userId !== request.user.sub) {
    return reply.status(403).send({ error: "Acesso negado." });
  }
}
