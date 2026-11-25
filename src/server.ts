import { buildApp } from "./app.js";
import { prisma } from "./lib/prisma.js";
import { startResetStreaksJob } from "./jobs/reset-streaks-job.js";

// O fuso define quando um "dia" começa. Reatribuir faz o Node aplicar o TZ vindo do .env.
if (process.env.TZ) process.env.TZ = process.env.TZ;

const jwtSecret = process.env.JWT_SECRET;

if (!jwtSecret) {
  throw new Error("JWT_SECRET não definido. Configure-o no arquivo .env");
}

const app = buildApp({
  jwtSecret,
  corsOrigin: process.env.CORS_ORIGIN,
  trustProxy: process.env.TRUST_PROXY === "true",
  logger: true,
});

const start = async () => {
  try {
    await app.listen({ port: Number(process.env.PORT) || 3333, host: "0.0.0.0" });
    const stopResetStreaksJob = startResetStreaksJob(app.log);

    // Desligamento limpo: termina as requisições em andamento e fecha o banco
    const shutdown = async () => {
      stopResetStreaksJob();
      await app.close();
      await prisma.$disconnect();
      process.exit(0);
    };
    process.once("SIGINT", shutdown);
    process.once("SIGTERM", shutdown);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
};

start();
