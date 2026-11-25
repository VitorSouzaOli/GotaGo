import { compare, hash } from "bcryptjs";
import { z } from "zod";

// Custo do bcrypt: 10 é o mínimo recomendado. Hashes antigos continuam válidos.
const SALT_ROUNDS = 10;

export const hashPassword = (password: string) => hash(password, SALT_ROUNDS);

export const verifyPassword = (password: string, passwordHash: string) =>
  compare(password, passwordHash);

// O bcrypt ignora tudo depois de 72 bytes, por isso o limite máximo
export const newPasswordSchema = z
  .string()
  .min(6, "Password must be at least 6 characters long")
  .max(72, "Password must be at most 72 characters long");
