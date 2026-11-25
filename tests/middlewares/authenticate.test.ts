import { FastifyReply, FastifyRequest } from "fastify";
import { describe, expect, it, vi } from "vitest";
import { authenticate } from "../../src/middlewares/authenticate.js";

function makeContext(jwtVerify: () => Promise<unknown>) {
  const reply = {
    status: vi.fn().mockReturnThis(),
    send: vi.fn().mockReturnThis(),
  };
  const request = { jwtVerify: vi.fn(jwtVerify) };

  return {
    reply,
    request,
    run: () =>
      authenticate(
        request as unknown as FastifyRequest,
        reply as unknown as FastifyReply,
      ),
  };
}

describe("authenticate", () => {
  it("deixa a requisição passar quando o token é válido", async () => {
    const { reply, request, run } = makeContext(async () => ({ sub: "abc" }));

    const result = await run();

    expect(request.jwtVerify).toHaveBeenCalledTimes(1);
    expect(reply.status).not.toHaveBeenCalled();
    expect(reply.send).not.toHaveBeenCalled();
    expect(result).toBeUndefined();
  });

  it("responde 401 quando o token é inválido, expirado ou ausente", async () => {
    const { reply, run } = makeContext(async () => {
      throw new Error("Authorization token is invalid");
    });

    await run();

    expect(reply.status).toHaveBeenCalledWith(401);
    expect(reply.send).toHaveBeenCalledWith({ error: "Token inválido ou ausente." });
  });

  it("não vaza o motivo técnico da falha para o cliente", async () => {
    const { reply, run } = makeContext(async () => {
      throw new Error("detalhe interno da biblioteca jwt");
    });

    await run();

    expect(JSON.stringify(reply.send.mock.calls[0][0])).not.toContain("biblioteca");
  });
});
