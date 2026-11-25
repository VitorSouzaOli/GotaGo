import { Prisma } from "@prisma/client";
import { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { authHeader, buildApp, LEAGUE_ID, OTHER_USER_ID, USER_ID } from "../helpers/build-app.js";
import { prismaMock } from "../helpers/prisma-mock.js";

vi.mock("../../src/lib/prisma.js", async () => {
  const { prismaMock } = await import("../helpers/prisma-mock.js");
  return { prisma: prismaMock };
});

import { leagueRoutes } from "../../src/routes/league-route.js";

let app: FastifyInstance;

const send = (method: "GET" | "POST" | "PATCH" | "DELETE", url: string, payload?: object) =>
  app.inject({ method, url, payload, headers: authHeader(app) });

const ownedBy = (ownerId: string) =>
  prismaMock.league.findUnique.mockResolvedValue({ id: LEAGUE_ID, ownerId });

beforeEach(async () => {
  app = await buildApp(leagueRoutes);
});

afterEach(async () => {
  await app.close();
});

const membership = {
  joinedAt: new Date("2026-11-01T12:00:00.000Z"),
  league: {
    id: LEAGUE_ID,
    name: "Liga",
    description: null,
    code: "GOTA-AB12",
    endDate: null,
    ownerId: USER_ID,
    _count: { members: 3 },
  },
};

describe("listagem de ligas", () => {
  it.each(["/leagues", `/users/${USER_ID}/leagues`])("GET %s", async (url) => {
    prismaMock.leagueMember.findMany.mockResolvedValue([membership]);

    const res = await send("GET", url);

    expect(res.json().leagues[0]).toMatchObject({ id: LEAGUE_ID, isOwner: true, memberCount: 3 });
  });

  it("nega as ligas de outra pessoa", async () => {
    expect((await send("GET", `/users/${OTHER_USER_ID}/leagues`)).statusCode).toBe(403);
  });
});

describe("GET /leagues/code/:code", () => {
  it.each(["gota-ab12", "GOTAAB12", "ab12"])("aceita o código digitado como %s", async (typed) => {
    prismaMock.league.findUnique.mockResolvedValue({
      id: LEAGUE_ID,
      name: "Liga",
      code: "GOTA-AB12",
      owner: { name: "Ana" },
      _count: { members: 2 },
    });

    const res = await send("GET", `/leagues/code/${typed}`);

    expect(prismaMock.league.findUnique.mock.calls[0][0].where).toEqual({ code: "GOTA-AB12" });
    expect(res.json().league).toEqual({
      id: LEAGUE_ID,
      name: "Liga",
      code: "GOTA-AB12",
      memberCount: 2,
      ownerName: "Ana",
    });
  });

  it("responde 404 para código inexistente", async () => {
    prismaMock.league.findUnique.mockResolvedValue(null);

    expect((await send("GET", "/leagues/code/ZZZZ")).statusCode).toBe(404);
  });
});

describe("regras ao entrar", () => {
  beforeEach(() => {
    prismaMock.user.findUnique.mockResolvedValue({ id: USER_ID });
    prismaMock.leagueMember.findUnique.mockResolvedValue(null);
  });

  it("recusa liga encerrada", async () => {
    prismaMock.league.findUnique.mockResolvedValue({ id: LEAGUE_ID, endDate: new Date(0) });

    const res = await send("POST", "/leagues/join", { code: "AB12" });

    expect(res.statusCode).toBe(400);
    expect(prismaMock.leagueMember.create).not.toHaveBeenCalled();
  });

  it("toque duplo vira a mensagem de 'já faz parte'", async () => {
    prismaMock.league.findUnique.mockResolvedValue({ id: LEAGUE_ID, endDate: null });
    prismaMock.leagueMember.create.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError("duplicado", { code: "P2002", clientVersion: "5" }),
    );

    const res = await send("POST", "/leagues/join", { code: "AB12" });

    expect(res.json()).toEqual({ error: "Já fazes parte desta liga." });
  });
});

describe.each([
  ["PATCH", `/leagues/${LEAGUE_ID}`],
  ["POST", `/leagues/${LEAGUE_ID}/code`],
] as const)("administração: %s %s", (method, url) => {
  it("só o administrador pode", async () => {
    ownedBy(OTHER_USER_ID);

    const res = await send(method, url, { name: "Novo nome" });

    expect(res.statusCode).toBe(403);
    expect(prismaMock.league.update).not.toHaveBeenCalled();
  });

  it("responde 404 se a liga não existe", async () => {
    prismaMock.league.findUnique.mockResolvedValue(null);

    expect((await send(method, url, { name: "Novo nome" })).statusCode).toBe(404);
  });
});

describe("ações do administrador", () => {
  it("renomeia a liga", async () => {
    ownedBy(USER_ID);
    prismaMock.league.update.mockResolvedValue({ id: LEAGUE_ID, name: "Novo nome" });

    const res = await send("PATCH", `/leagues/${LEAGUE_ID}`, { name: "Novo nome" });

    expect(res.statusCode).toBe(200);
    expect(prismaMock.league.update.mock.calls[0][0].data).toEqual({ name: "Novo nome" });
  });

  it("gera um novo código", async () => {
    prismaMock.league.findUnique
      .mockResolvedValueOnce({ id: LEAGUE_ID, ownerId: USER_ID })
      .mockResolvedValue(null);

    const res = await send("POST", `/leagues/${LEAGUE_ID}/code`);

    expect(res.json().code).toMatch(/^GOTA-[A-Z0-9]{4}$/);
  });
});

describe("DELETE /leagues/:id/members/:userId", () => {
  const remove = (userId: string) => send("DELETE", `/leagues/${LEAGUE_ID}/members/${userId}`);

  beforeEach(() => {
    prismaMock.leagueMember.deleteMany.mockResolvedValue({ count: 1 });
  });

  it("um membro pode sair", async () => {
    ownedBy(OTHER_USER_ID);

    expect((await remove(USER_ID)).statusCode).toBe(204);
    expect(prismaMock.league.update).not.toHaveBeenCalled();
  });

  it("um membro não remove outro", async () => {
    ownedBy(OTHER_USER_ID);

    expect((await remove(OTHER_USER_ID)).statusCode).toBe(403);
    expect(prismaMock.leagueMember.deleteMany).not.toHaveBeenCalled();
  });

  it("quando o administrador sai, o membro mais antigo assume", async () => {
    ownedBy(USER_ID);
    prismaMock.leagueMember.findFirst.mockResolvedValue({ userId: OTHER_USER_ID });

    await remove(USER_ID);

    expect(prismaMock.league.update.mock.calls[0][0].data).toEqual({ ownerId: OTHER_USER_ID });
  });

  it("apaga a liga que ficou vazia", async () => {
    ownedBy(USER_ID);
    prismaMock.leagueMember.findFirst.mockResolvedValue(null);

    await remove(USER_ID);

    expect(prismaMock.league.delete).toHaveBeenCalledWith({ where: { id: LEAGUE_ID } });
  });

  it("responde 404 se a pessoa não participa", async () => {
    ownedBy(USER_ID);
    prismaMock.leagueMember.deleteMany.mockResolvedValue({ count: 0 });

    expect((await remove(OTHER_USER_ID)).statusCode).toBe(404);
  });

  it("responde 404 se a liga não existe", async () => {
    prismaMock.league.findUnique.mockResolvedValue(null);

    expect((await remove(USER_ID)).statusCode).toBe(404);
  });
});
