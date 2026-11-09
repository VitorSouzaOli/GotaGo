import Fastify from "fastify";
import cors from "@fastify/cors";
import jwt from "@fastify/jwt";
import { userRoutes } from "./routes/user-routes.js";
import { sessionRoutes } from "./routes/session-routes.js";
import { waterLogRoutes } from "./routes/water-logs-route.js";
import { leagueRoutes } from "./routes/league-route.js";
import { achievementRoutes } from "./routes/achieviments-route.js";

const app = Fastify({
  logger: true,
});

const jwtSecret = process.env.JWT_SECRET;

if (!jwtSecret) {
  throw new Error("JWT_SECRET não definido. Configure-o no arquivo .env");
}

// CORS: define quais origens (sites) podem chamar a API pelo navegador.
// Sem CORS_ORIGIN no .env, libera todas (útil em desenvolvimento).
app.register(cors, {
  origin: process.env.CORS_ORIGIN
    ? process.env.CORS_ORIGIN.split(",").map((origin) => origin.trim())
    : true,
});

// JWT: habilita criar (jwtSign) e verificar (jwtVerify) tokens com a chave secreta.
app.register(jwt, {
  secret: jwtSecret,
});

app.get("/health", async () => {
  return { status: "ok", service: "GotaGo API" };
});

// Registrar as rotas da aplicação
app.register(userRoutes);
app.register(sessionRoutes);
app.register(waterLogRoutes);
app.register(leagueRoutes);
app.register(achievementRoutes);

const start = async () => {
  try {
    await app.listen({ port: 3333, host: "0.0.0.0" });
    console.log("🚀 HTTP Server running on http://localhost:3333");
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
};

start();
