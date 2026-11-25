import { FastifyBaseLogger } from "fastify";

// Ainda não há provedor de e-mail configurado. Em desenvolvimento o link aparece no
// terminal do servidor; troque o corpo desta função pelo envio real (SMTP, Resend etc.).
export async function sendPasswordResetEmail(
  email: string,
  link: string,
  log: FastifyBaseLogger,
) {
  if (process.env.NODE_ENV === "production") {
    log.warn("Envio de e-mail não configurado: o link de recuperação de senha não foi enviado.");
    return;
  }
  log.info(`Recuperação de senha de ${email}: ${link}`);
}
