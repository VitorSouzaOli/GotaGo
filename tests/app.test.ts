import { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { prismaMock } from "./helpers/prisma-mock.js";

vi.mock("../src/lib/prisma.js", async () => {
  const { prismaMock } = await import("./helpers/prisma-mock.js");
  return { prisma: prismaMock };
});

import { buildApp } from "../src/app.js";

let app: FastifyInstance;

beforeEach(async () => {
  app = buildApp({ jwtSecret: "segredo-somente-para-testes" });
  await app.ready();
});

afterEach(async () => {
  await app.close();
});

describe("aplicação completa", () => {
  it("responde o health check", async () => {
    const res = await app.inject({ method: "GET", url: "/health" });

    expect(res.json()).toEqual({ status: "ok", service: "GotaGo API" });
  });

  it.each(["PATCH", "DELETE"])("libera %s no CORS", async (method) => {
    const res = await app.inject({
      method: "OPTIONS",
      url: "/water-logs/qualquer",
      headers: { origin: "http://localhost:5000", "access-control-request-method": method },
    });

    expect(res.headers["access-control-allow-methods"]).toContain(method);
  });

  it("bloqueia com 429 depois de muitas tentativas de login", async () => {
    prismaMock.user.findFirst.mockResolvedValue(null);
    const attempt = () =>
      app.inject({ method: "POST", url: "/sessions", payload: { login: "ana", password: "x" } });

    for (let i = 0; i < 10; i++) expect((await attempt()).statusCode).toBe(400);
    const blocked = await attempt();

    expect(blocked.statusCode).toBe(429);
    expect(blocked.headers["retry-after"]).toBeDefined();
  });
});
