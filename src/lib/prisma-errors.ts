import { Prisma } from "@prisma/client";

// P2002 = violação de índice único (ex.: duas requisições criando o mesmo registro)
export function isUniqueViolation(error: unknown): error is Prisma.PrismaClientKnownRequestError {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002";
}
