import { FastifyReply, FastifyRequest } from "fastify";

// Limite simples de tentativas por IP, em memória (suficiente para um único servidor).
// Protege login, recuperação de senha e códigos de convite contra força bruta.
export function rateLimit(max: number, windowMs = 60_000) {
  const hits = new Map<string, { count: number; resetAt: number }>();

  return async function rateLimitHook(request: FastifyRequest, reply: FastifyReply) {
    const now = Date.now();

    // Evita que o mapa cresça sem parar
    if (hits.size >= 10_000) {
      for (const [key, entry] of hits) if (entry.resetAt <= now) hits.delete(key);
    }

    let entry = hits.get(request.ip);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowMs };
      hits.set(request.ip, entry);
    }

    if (++entry.count > max) {
      reply.header("retry-after", Math.ceil((entry.resetAt - now) / 1000));
      return reply.status(429).send({ error: "Muitas tentativas. Aguarde um pouco e tente de novo." });
    }
  };
}
