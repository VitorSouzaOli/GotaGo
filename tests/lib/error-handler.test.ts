import { FastifyError, FastifyReply, FastifyRequest } from "fastify";
import { describe, expect, it, vi } from "vitest";
import { z } from "zod";
import { errorHandler } from "../../src/lib/error-handler.js";

// Objetos mínimos no lugar do request/reply reais do Fastify
function makeContext() {
  const reply = {
    status: vi.fn().mockReturnThis(),
    send: vi.fn().mockReturnThis(),
  };
  const request = { log: { error: vi.fn() } };

  return {
    reply,
    request,
    run: (error: Error) =>
      errorHandler(
        error as FastifyError,
        request as unknown as FastifyRequest,
        reply as unknown as FastifyReply,
      ),
  };
}

function httpError(message: string, statusCode: number): FastifyError {
  return Object.assign(new Error(message), { statusCode }) as FastifyError;
}

describe("errorHandler", () => {
  describe("erros de validação do Zod", () => {
    it("responde 400 com a lista de campos inválidos", () => {
      const schema = z.object({
        email: z.email("E-mail inválido"),
        age: z.number("Idade deve ser número"),
      });
      const { error } = schema.safeParse({ email: "x", age: "dez" });
      const { reply, run } = makeContext();

      run(error!);

      expect(reply.status).toHaveBeenCalledWith(400);
      expect(reply.send).toHaveBeenCalledWith({
        error: "Dados inválidos.",
        issues: [
          { field: "email", message: "E-mail inválido" },
          { field: "age", message: "Idade deve ser número" },
        ],
      });
    });

    it("junta o caminho de campos aninhados com ponto", () => {
      const schema = z.object({ user: z.object({ name: z.string().min(2, "curto") }) });
      const { error } = schema.safeParse({ user: { name: "A" } });
      const { reply, run } = makeContext();

      run(error!);

      expect(reply.send).toHaveBeenCalledWith({
        error: "Dados inválidos.",
        issues: [{ field: "user.name", message: "curto" }],
      });
    });

    it("usa campo vazio quando o erro é na raiz (ex.: corpo ausente)", () => {
      const { error } = z.object({ a: z.string() }).safeParse(undefined);
      const { reply, run } = makeContext();

      run(error!);

      const body = reply.send.mock.calls[0][0];
      expect(body.issues).toHaveLength(1);
      expect(body.issues[0].field).toBe("");
    });

    it("não registra no log (erro do cliente, não do servidor)", () => {
      const { error } = z.string().safeParse(1);
      const { request, run } = makeContext();

      run(error!);

      expect(request.log.error).not.toHaveBeenCalled();
    });
  });

  describe("erros HTTP 4xx do Fastify", () => {
    it.each([
      [400, "Body is not valid JSON"],
      [401, "Não autorizado"],
      [404, "Rota não encontrada"],
      [413, "Corpo grande demais"],
      [429, "Muitas requisições"],
      [499, "Limite superior dos 4xx"],
    ])("mantém o status %s e a mensagem original", (statusCode, message) => {
      const { reply, run } = makeContext();

      run(httpError(message, statusCode));

      expect(reply.status).toHaveBeenCalledWith(statusCode);
      expect(reply.send).toHaveBeenCalledWith({ error: message });
    });

    it("não registra no log", () => {
      const { request, run } = makeContext();

      run(httpError("nope", 404));

      expect(request.log.error).not.toHaveBeenCalled();
    });
  });

  describe("erros inesperados (viram 500)", () => {
    it("responde 500 genérico para um Error comum", () => {
      const { reply, run } = makeContext();

      run(new Error("falha interna"));

      expect(reply.status).toHaveBeenCalledWith(500);
      expect(reply.send).toHaveBeenCalledWith({ error: "Erro interno do servidor." });
    });

    it("não vaza a mensagem interna para o cliente", () => {
      const { reply, run } = makeContext();

      run(new Error("senha do banco: 123"));

      expect(JSON.stringify(reply.send.mock.calls[0][0])).not.toContain("senha do banco");
    });

    it("registra o erro original no log do servidor", () => {
      const { request, run } = makeContext();
      const error = new Error("falha interna");

      run(error);

      expect(request.log.error).toHaveBeenCalledWith(error);
    });

    it("trata 5xx do Fastify como 500 genérico (sem repassar a mensagem)", () => {
      const { reply, request, run } = makeContext();

      run(httpError("detalhe interno", 503));

      expect(reply.status).toHaveBeenCalledWith(500);
      expect(reply.send).toHaveBeenCalledWith({ error: "Erro interno do servidor." });
      expect(request.log.error).toHaveBeenCalled();
    });

    it.each([200, 302, 399])("trata statusCode %s (fora de 4xx) como 500", (statusCode) => {
      const { reply, run } = makeContext();

      run(httpError("estranho", statusCode));

      expect(reply.status).toHaveBeenCalledWith(500);
    });

    it("trata statusCode 400 exato como erro do cliente (limite inferior)", () => {
      const { reply, run } = makeContext();

      run(httpError("ruim", 400));

      expect(reply.status).toHaveBeenCalledWith(400);
    });
  });
});
