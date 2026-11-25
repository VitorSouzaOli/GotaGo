import Fastify, { FastifyInstance, FastifyPluginAsync } from "fastify";
import jwt from "@fastify/jwt";
import { errorHandler } from "../../src/lib/error-handler.js";

export const TEST_JWT_SECRET = "segredo-somente-para-testes";

// IDs fixos no formato UUID v4 (o Zod valida o formato)
export const USER_ID = "3f2b8c1e-5d4a-4b7e-9a6c-1d2e3f4a5b6c";
export const OTHER_USER_ID = "7a1c9e2d-8b3f-4c5a-b6d7-0e1f2a3b4c5d";
export const LEAGUE_ID = "9c8b7a6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d";

// Monta uma API igual à do server.ts (JWT + tratador de erros), mas só com as rotas informadas
// e sem abrir porta de rede: os testes usam app.inject().
export async function buildApp(...routes: FastifyPluginAsync[]): Promise<FastifyInstance> {
  const app = Fastify();

  app.register(jwt, { secret: TEST_JWT_SECRET });
  for (const route of routes) {
    app.register(route);
  }
  app.setErrorHandler(errorHandler);

  await app.ready();
  return app;
}

// Cabeçalho "Authorization: Bearer <token>" para o usuário informado
export function authHeader(app: FastifyInstance, userId: string = USER_ID) {
  return { authorization: `Bearer ${app.jwt.sign({ sub: userId })}` };
}
