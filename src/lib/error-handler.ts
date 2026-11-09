import { FastifyError, FastifyReply, FastifyRequest } from "fastify";
import { ZodError } from "zod";

// Tratador global de erros: qualquer erro não tratado dentro de uma rota cai aqui.
export function errorHandler(
  error: FastifyError | ZodError,
  request: FastifyRequest,
  reply: FastifyReply,
) {
  // Dados inválidos (falhou no schema do Zod) -> 400 com a lista dos campos errados
  if (error instanceof ZodError) {
    return reply.status(400).send({
      error: "Dados inválidos.",
      issues: error.issues.map((issue) => ({
        field: issue.path.join("."),
        message: issue.message,
      })),
    });
  }

  // Erros HTTP do próprio Fastify (ex.: JSON malformado) já trazem o status correto
  if (error.statusCode && error.statusCode >= 400 && error.statusCode < 500) {
    return reply.status(error.statusCode).send({ error: error.message });
  }

  // Qualquer outra coisa é um bug nosso: registra no log e não expõe detalhes ao cliente
  request.log.error(error);
  return reply.status(500).send({ error: "Erro interno do servidor." });
}
