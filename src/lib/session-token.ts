import { FastifyReply } from "fastify";

// Token de sessão: "sub" guarda o ID do utilizador e ele expira em 7 dias
export const signSessionToken = (reply: FastifyReply, userId: string) =>
  reply.jwtSign({ sub: userId }, { expiresIn: "7d" });
