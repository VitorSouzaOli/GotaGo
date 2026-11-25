import { PrismaClient } from "@prisma/client";

// Registrar cada consulta SQL deixa o servidor lento e o log ilegível:
// ligue com PRISMA_LOG_QUERIES=true só quando precisar depurar.
export const prisma = new PrismaClient({
  log: process.env.PRISMA_LOG_QUERIES === "true" ? ["query", "warn", "error"] : ["warn", "error"],
});
