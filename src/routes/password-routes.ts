import { createHash, randomBytes } from "node:crypto";
import { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { sendPasswordResetEmail } from "../lib/mailer.js";
import { hashPassword, newPasswordSchema } from "../lib/password.js";
import { rateLimit } from "../middlewares/rate-limit.js";
import { resetPasswordPage, resetPasswordPageHeaders } from "../utils/reset-password-page.js";

const TOKEN_TTL_MS = 60 * 60 * 1000; // 1 hora

// No banco fica só o hash: quem ler a tabela não consegue usar os links
const hashToken = (token: string) => createHash("sha256").update(token).digest("hex");

export async function passwordRoutes(app: FastifyInstance) {
  // Pede o link de recuperação
  app.post(
    "/passwords/forgot",
    { onRequest: [rateLimit(5, 15 * 60_000)] },
    async (request, reply) => {
      const bodySchema = z.object({
        email: z.string().trim().toLowerCase().pipe(z.email("Invalid email address")),
      });

      const { email } = bodySchema.parse(request.body);
      const user = await prisma.user.findUnique({ where: { email } });

      if (user) {
        const token = randomBytes(32).toString("base64url");

        // Um pedido novo invalida os links anteriores
        await prisma.$transaction([
          prisma.passwordResetToken.deleteMany({ where: { userId: user.id } }),
          prisma.passwordResetToken.create({
            data: {
              userId: user.id,
              tokenHash: hashToken(token),
              expiresAt: new Date(Date.now() + TOKEN_TTL_MS),
            },
          }),
        ]);

        // O token vai depois do "#": o navegador não o envia ao servidor, então não cai no log
        const baseUrl = (process.env.APP_URL || "http://localhost:3333").replace(/\/$/, "");
        await sendPasswordResetEmail(
          user.email,
          `${baseUrl}/passwords/reset#token=${token}`,
          request.log,
        );
      }

      // Mesma resposta com ou sem conta: não revela quais e-mails estão cadastrados
      return reply.status(202).send({
        message: "Se o e-mail estiver cadastrado, enviaremos as instruções.",
      });
    },
  );

  // Página aberta pelo link do e-mail
  app.get("/passwords/reset", async (_request, reply) => {
    return reply.headers(resetPasswordPageHeaders).send(resetPasswordPage);
  });

  // Grava a nova senha
  app.post("/passwords/reset", { onRequest: [rateLimit(10)] }, async (request, reply) => {
    const bodySchema = z.object({
      token: z.string().min(1, "Token is required").max(200),
      password: newPasswordSchema,
    });

    const { token, password } = bodySchema.parse(request.body);
    const passwordHash = await hashPassword(password);

    const changed = await prisma.$transaction(async (tx) => {
      const record = await tx.passwordResetToken.findUnique({
        where: { tokenHash: hashToken(token) },
      });
      if (!record || record.expiresAt <= new Date()) return false;

      // Apagar antes de usar garante que o link funcione uma única vez
      const { count } = await tx.passwordResetToken.deleteMany({ where: { id: record.id } });
      if (count === 0) return false;

      await tx.user.update({ where: { id: record.userId }, data: { passwordHash } });
      return true;
    });

    if (!changed) {
      return reply.status(400).send({ error: "Link inválido ou expirado. Peça um novo." });
    }

    return reply.status(204).send();
  });
}
