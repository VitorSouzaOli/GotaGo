import Fastify, { FastifyServerOptions } from "fastify";
import cors from "@fastify/cors";
import jwt from "@fastify/jwt";
import { userRoutes } from "./routes/user-routes.js";
import { sessionRoutes } from "./routes/session-routes.js";
import { passwordRoutes } from "./routes/password-routes.js";
import { waterLogRoutes } from "./routes/water-logs-route.js";
import { leagueRoutes } from "./routes/league-route.js";
import { achievementRoutes } from "./routes/achieviments-route.js";
import { errorHandler } from "./lib/error-handler.js";

export interface AppOptions {
  jwtSecret: string;
  /** Origens permitidas, separadas por vírgula. Vazio = libera todas. */
  corsOrigin?: string;
  logger?: FastifyServerOptions["logger"];
  /** Ligue quando houver um proxy na frente, para o limite por IP enxergar o cliente real */
  trustProxy?: boolean;
}

// Monta a API sem abrir porta de rede (o server.ts faz isso; os testes usam app.inject)
export function buildApp({ jwtSecret, corsOrigin, logger = false, trustProxy = false }: AppOptions) {
  const app = Fastify({ logger, trustProxy });

  // Tratamento global de erros (Zod, erros HTTP e falhas inesperadas)
  app.setErrorHandler(errorHandler);

  // CORS: define quais origens (sites) podem chamar a API pelo navegador.
  app.register(cors, {
    origin: corsOrigin ? corsOrigin.split(",").map((origin) => origin.trim()) : true,
    // sem esta lista o plugin só libera GET, HEAD e POST
    methods: ["GET", "HEAD", "POST", "PATCH", "DELETE"],
  });

  // JWT: habilita criar (jwtSign) e verificar (jwtVerify) tokens com a chave secreta.
  app.register(jwt, { secret: jwtSecret });

  app.get("/health", async () => {
    return { status: "ok", service: "GotaGo API" };
  });

  // Registrar as rotas da aplicação
  app.register(userRoutes);
  app.register(sessionRoutes);
  app.register(passwordRoutes);
  app.register(waterLogRoutes);
  app.register(leagueRoutes);
  app.register(achievementRoutes);

  return app;
}
