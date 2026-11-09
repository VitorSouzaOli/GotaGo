import Fastify from "fastify";
import { userRoutes } from "./routes/user-routes.js";
import { sessionRoutes } from "./routes/session-routes.js";
import { waterLogRoutes } from "./routes/water-logs-route.js";
import { leagueRoutes } from "./routes/league-route.js";
import { achievementRoutes } from "./routes/achieviments-route.js";
import { errorHandler } from "./lib/error-handler.js";

const app = Fastify({
  logger: true,
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

// Tratamento global de erros (Zod, erros HTTP e falhas inesperadas)
app.setErrorHandler(errorHandler);

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
