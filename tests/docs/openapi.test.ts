import { FastifyInstance } from "fastify";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

vi.mock("../../src/lib/prisma.js", async () => {
  const { prismaMock } = await import("../helpers/prisma-mock.js");
  return { prisma: prismaMock };
});

import { buildApp } from "../../src/app.js";

const METHODS = ["get", "post", "put", "patch", "delete"];

let app: FastifyInstance;
// "POST /water-logs/{id}" de cada rota registrada na API
const registered = new Set<string>();

beforeAll(async () => {
  app = buildApp({ jwtSecret: "segredo-somente-para-testes" });
  app.addHook("onRoute", (route) => {
    // As rotas do próprio Swagger UI não entram na documentação
    if (route.url.startsWith("/docs")) return;
    const methods = Array.isArray(route.method) ? route.method : [route.method];
    for (const method of methods) {
      if (method === "HEAD" || method === "OPTIONS") continue;
      registered.add(`${method} ${route.url.replace(/:(\w+)/g, "{$1}")}`);
    }
  });
  await app.ready();
});

afterAll(async () => {
  await app.close();
});

function documented(): Set<string> {
  const spec = app.swagger() as { paths: Record<string, Record<string, unknown>> };
  const operations = new Set<string>();
  for (const [path, item] of Object.entries(spec.paths)) {
    for (const method of Object.keys(item)) {
      if (METHODS.includes(method)) operations.add(`${method.toUpperCase()} ${path}`);
    }
  }
  return operations;
}

describe("documentação OpenAPI (docs/openapi.yaml)", () => {
  it("é OpenAPI 3 com autenticação Bearer", () => {
    const spec = app.swagger() as Record<string, any>;

    expect(spec.openapi).toMatch(/^3\./);
    expect(spec.components.securitySchemes.bearerAuth.scheme).toBe("bearer");
  });

  it("documenta todas as rotas da API", () => {
    const missing = [...registered].filter((op) => !documented().has(op));

    expect(missing).toEqual([]);
  });

  it("não documenta rotas que não existem", () => {
    const extra = [...documented()].filter((op) => !registered.has(op));

    expect(extra).toEqual([]);
  });

  it("serve o Swagger UI em /docs e o JSON em /docs/json", async () => {
    const page = await app.inject({ method: "GET", url: "/docs/" });
    const json = await app.inject({ method: "GET", url: "/docs/json" });

    expect(page.statusCode).toBe(200);
    expect(page.headers["content-type"]).toContain("text/html");
    expect(json.json().info.title).toBe("GotaGo API");
  });
});
