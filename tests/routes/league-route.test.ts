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

const send = (method: "GET" | "POST", url: string, payload?: unknown, headers = authHeader(app)) =>
  app.inject({ method, url, headers, payload: payload as object });

beforeEach(async () => {
  app = await buildApp(leagueRoutes);
});

afterEach(async () => {
  vi.restoreAllMocks();
  await app.close();
});

describe("POST /leagues (criar liga)", () => {
  beforeEach(() => {
    prismaMock.user.findUnique.mockResolvedValue({ id: USER_ID });
    prismaMock.league.findUnique.mockResolvedValue(null);
    prismaMock.league.create.mockImplementation(async ({ data }) => ({
      id: LEAGUE_ID,
      ...data,
      members: [{ userId: data.ownerId }],
    }));
  });

  describe("autenticação e validação", () => {
    it("responde 401 sem token", async () => {
      const res = await send("POST", "/leagues", { name: "Liga" }, {} as never);

      expect(res.statusCode).toBe(401);
      expect(prismaMock.league.create).not.toHaveBeenCalled();
    });

    it.each([
      ["nome curto", { name: "ab" }, "name"],
      ["nome ausente", {}, "name"],
      ["nome como número", { name: 123 }, "name"],
      ["descrição como número", { name: "Liga", description: 5 }, "description"],
      ["endDate fora do formato ISO", { name: "Liga", endDate: "amanhã" }, "endDate"],
      ["endDate só com a data", { name: "Liga", endDate: "2026-12-31" }, "endDate"],
      ["endDate impossível", { name: "Liga", endDate: "2026-13-45T00:00:00Z" }, "endDate"],
    ])("rejeita %s com 400", async (_nome, payload, field) => {
      const res = await send("POST", "/leagues", payload);

      expect(res.statusCode).toBe(400);
      expect(res.json().issues.map((i: { field: string }) => i.field)).toContain(field);
      expect(prismaMock.league.create).not.toHaveBeenCalled();
    });

    it("aceita nome com exatamente 3 caracteres", async () => {
      const res = await send("POST", "/leagues", { name: "abc" });

      expect(res.statusCode).toBe(201);
    });
  });

  describe("criação", () => {
    it("responde 404 se o criador não existe mais", async () => {
      prismaMock.user.findUnique.mockResolvedValue(null);

      const res = await send("POST", "/leagues", { name: "Liga dos Amigos" });

      expect(res.statusCode).toBe(404);
      expect(res.json()).toEqual({ error: "Utilizador criador não encontrado." });
      expect(prismaMock.league.create).not.toHaveBeenCalled();
    });

    it("cria a liga, torna o criador dono e primeiro membro", async () => {
      const res = await send("POST", "/leagues", {
        name: "Liga dos Amigos",
        description: "Quem bebe mais água",
      });

      expect(res.statusCode).toBe(201);
      const call = prismaMock.league.create.mock.calls[0][0];
      expect(call.data).toMatchObject({
        name: "Liga dos Amigos",
        description: "Quem bebe mais água",
        ownerId: USER_ID,
        endDate: null,
        members: { create: { userId: USER_ID } },
      });
      expect(call.include).toEqual({ members: true });
      expect(res.json().league.id).toBe(LEAGUE_ID);
    });

    it("usa o dono do token e ignora um ownerId enviado no corpo", async () => {
      await send("POST", "/leagues", { name: "Liga dos Amigos", ownerId: OTHER_USER_ID });

      expect(prismaMock.league.create.mock.calls[0][0].data.ownerId).toBe(USER_ID);
      expect(prismaMock.user.findUnique).toHaveBeenCalledWith({ where: { id: USER_ID } });
    });

    it("converte endDate para Date", async () => {
      await send("POST", "/leagues", { name: "Liga", endDate: "2026-12-31T23:59:59.000Z" });

      const { endDate } = prismaMock.league.create.mock.calls[0][0].data;
      expect(endDate).toBeInstanceOf(Date);
      expect(endDate.toISOString()).toBe("2026-12-31T23:59:59.000Z");
    });

    it("deixa a descrição indefinida quando não enviada", async () => {
      await send("POST", "/leagues", { name: "Liga" });

      expect(prismaMock.league.create.mock.calls[0][0].data.description).toBeUndefined();
    });
  });

  describe("código de convite", () => {
    it("gera o formato GOTA-XXXX com letras maiúsculas e números", async () => {
      const res = await send("POST", "/leagues", { name: "Liga" });

      expect(res.json().league.code).toMatch(/^GOTA-[A-Z0-9]{4}$/);
    });

    it("usa o primeiro caractere (A) quando o sorteio dá 0", async () => {
      vi.spyOn(Math, "random").mockReturnValue(0);

      const res = await send("POST", "/leagues", { name: "Liga" });

      expect(res.json().league.code).toBe("GOTA-AAAA");
    });

    it("usa o último caractere (9) quando o sorteio dá quase 1", async () => {
      vi.spyOn(Math, "random").mockReturnValue(0.9999);

      const res = await send("POST", "/leagues", { name: "Liga" });

      expect(res.json().league.code).toBe("GOTA-9999");
    });

    it("sorteia outro código enquanto o gerado já existir", async () => {
      const random = vi.spyOn(Math, "random");
      // 1º código AAAA (existe), 2º SSSS (existe), 3º 9999 (livre)
      [0, 0, 0, 0, 0.5, 0.5, 0.5, 0.5, 0.9999, 0.9999, 0.9999, 0.9999].forEach((v) =>
        random.mockReturnValueOnce(v),
      );
      prismaMock.league.findUnique
        .mockResolvedValueOnce({ id: "existente-1" })
        .mockResolvedValueOnce({ id: "existente-2" })
        .mockResolvedValueOnce(null);

      const res = await send("POST", "/leagues", { name: "Liga" });

      const consultados = prismaMock.league.findUnique.mock.calls.map(([arg]) => arg.where.code);
      expect(consultados).toEqual(["GOTA-AAAA", "GOTA-SSSS", "GOTA-9999"]);
      expect(prismaMock.league.create.mock.calls[0][0].data.code).toBe("GOTA-9999");
      expect(res.json().league.code).toBe("GOTA-9999");
    });
  });

  it("responde 500 genérico se o banco falhar ao criar", async () => {
    prismaMock.league.create.mockRejectedValue(new Error("falha"));

    const res = await send("POST", "/leagues", { name: "Liga" });

    expect(res.statusCode).toBe(500);
    expect(res.json()).toEqual({ error: "Erro interno do servidor." });
  });
});

describe("POST /leagues/join (entrar numa liga)", () => {
  const league = { id: LEAGUE_ID, name: "Liga dos Amigos", code: "GOTA-AB12" };

  beforeEach(() => {
    prismaMock.user.findUnique.mockResolvedValue({ id: USER_ID });
    prismaMock.league.findUnique.mockResolvedValue(league);
    prismaMock.leagueMember.findUnique.mockResolvedValue(null);
    prismaMock.leagueMember.create.mockImplementation(async ({ data }) => ({ id: "m-1", ...data }));
  });

  it("responde 401 sem token", async () => {
    const res = await send("POST", "/leagues/join", { code: "GOTA-AB12" }, {} as never);

    expect(res.statusCode).toBe(401);
  });

  it.each([
    ["código vazio", { code: "" }],
    ["código ausente", {}],
    ["código como número", { code: 123 }],
  ])("rejeita %s com 400", async (_nome, payload) => {
    const res = await send("POST", "/leagues/join", payload);

    expect(res.statusCode).toBe(400);
    expect(res.json().issues[0].field).toBe("code");
  });

  it("entra na liga e responde 201 com a mensagem e a participação", async () => {
    const res = await send("POST", "/leagues/join", { code: "GOTA-AB12" });

    expect(res.statusCode).toBe(201);
    expect(res.json().message).toBe("Entraste na liga 'Liga dos Amigos' com sucesso!");
    expect(res.json().membership).toEqual({ id: "m-1", leagueId: LEAGUE_ID, userId: USER_ID });
    expect(prismaMock.leagueMember.create).toHaveBeenCalledWith({
      data: { leagueId: LEAGUE_ID, userId: USER_ID },
    });
  });

  it("aceita o código em minúsculas (converte para maiúsculas)", async () => {
    await send("POST", "/leagues/join", { code: "gota-ab12" });

    expect(prismaMock.league.findUnique).toHaveBeenCalledWith({ where: { code: "GOTA-AB12" } });
  });

  it("entra com o usuário do token e ignora um userId do corpo", async () => {
    await send("POST", "/leagues/join", { code: "GOTA-AB12", userId: OTHER_USER_ID });

    expect(prismaMock.user.findUnique).toHaveBeenCalledWith({ where: { id: USER_ID } });
    expect(prismaMock.leagueMember.create.mock.calls[0][0].data.userId).toBe(USER_ID);
  });

  it("verifica a participação pela chave composta liga + usuário", async () => {
    await send("POST", "/leagues/join", { code: "GOTA-AB12" });

    expect(prismaMock.leagueMember.findUnique).toHaveBeenCalledWith({
      where: { leagueId_userId: { leagueId: LEAGUE_ID, userId: USER_ID } },
    });
  });

  it("responde 404 se o usuário do token não existe", async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);

    const res = await send("POST", "/leagues/join", { code: "GOTA-AB12" });

    expect(res.statusCode).toBe(404);
    expect(res.json()).toEqual({ error: "Utilizador não encontrado." });
  });

  it("responde 404 se nenhuma liga tem esse código", async () => {
    prismaMock.league.findUnique.mockResolvedValue(null);

    const res = await send("POST", "/leagues/join", { code: "GOTA-ZZZZ" });

    expect(res.statusCode).toBe(404);
    expect(res.json()).toEqual({ error: "Liga não encontrada com este código." });
    expect(prismaMock.leagueMember.create).not.toHaveBeenCalled();
  });

  it("responde 400 se já faz parte da liga e não duplica a participação", async () => {
    prismaMock.leagueMember.findUnique.mockResolvedValue({ id: "m-0" });

    const res = await send("POST", "/leagues/join", { code: "GOTA-AB12" });

    expect(res.statusCode).toBe(400);
    expect(res.json()).toEqual({ error: "Já fazes parte desta liga." });
    expect(prismaMock.leagueMember.create).not.toHaveBeenCalled();
  });
});

describe("GET /leagues/:id/leaderboard (ranking)", () => {
  const member = (id: string, streak: number) => ({
    user: {
      id,
      name: `Nome ${id}`,
      username: id,
      avatarUrl: null,
      currentStreak: streak,
      maxStreak: streak + 1,
    },
  });

  const leagueWith = (...members: ReturnType<typeof member>[]) => ({
    id: LEAGUE_ID,
    name: "Liga dos Amigos",
    description: "desc",
    code: "GOTA-AB12",
    ownerId: USER_ID,
    members,
  });

  const getLeaderboard = (id: string = LEAGUE_ID, headers = authHeader(app)) =>
    send("GET", `/leagues/${id}/leaderboard`, undefined, headers);

  // quem consulta (o dono do token) precisa estar entre os membros
  const me = () => member(USER_ID, 0);

  it("responde 401 sem token", async () => {
    const res = await getLeaderboard(LEAGUE_ID, {} as never);

    expect(res.statusCode).toBe(401);
  });

  it("responde 400 com id que não é UUID", async () => {
    const res = await getLeaderboard("123");

    expect(res.statusCode).toBe(400);
    expect(res.json().issues[0].field).toBe("id");
    expect(prismaMock.league.findUnique).not.toHaveBeenCalled();
  });

  it("responde 404 quando a liga não existe", async () => {
    prismaMock.league.findUnique.mockResolvedValue(null);

    const res = await getLeaderboard();

    expect(res.statusCode).toBe(404);
    expect(res.json()).toEqual({ error: "Liga não encontrada." });
  });

  it("ordena do maior streak para o menor", async () => {
    prismaMock.league.findUnique.mockResolvedValue(
      leagueWith(member("ana", 2), member("bia", 9), member("caio", 5), me()),
    );

    const res = await getLeaderboard();

    expect(res.statusCode).toBe(200);
    expect(res.json().leaderboard.map((u: { id: string }) => u.id)).toEqual(["bia", "caio", "ana", USER_ID]);
  });

  it("mantém a ordem de entrada em caso de empate no streak", async () => {
    prismaMock.league.findUnique.mockResolvedValue(
      leagueWith(member("ana", 3), member("bia", 3), member("caio", 3), me()),
    );

    const res = await getLeaderboard();

    expect(res.json().leaderboard.map((u: { id: string }) => u.id)).toEqual(["ana", "bia", "caio", USER_ID]);
  });

  it("devolve os dados da liga, com o dono e sem os membros crus", async () => {
    prismaMock.league.findUnique.mockResolvedValue(leagueWith(me()));

    const res = await getLeaderboard();

    expect(res.json().league).toEqual({
      id: LEAGUE_ID,
      name: "Liga dos Amigos",
      description: "desc",
      code: "GOTA-AB12",
      ownerId: USER_ID,
    });
  });

  it("responde 403 para quem não participa e não revela o código", async () => {
    prismaMock.league.findUnique.mockResolvedValue(leagueWith(member("ana", 1)));

    const res = await getLeaderboard();

    expect(res.statusCode).toBe(403);
    expect(res.body).not.toContain("GOTA-AB12");
  });

  it("pede ao banco somente campos seguros do usuário (sem e-mail nem senha)", async () => {
    prismaMock.league.findUnique.mockResolvedValue(leagueWith());

    await getLeaderboard();

    const select = prismaMock.league.findUnique.mock.calls[0][0].include.members.include.user.select;
    expect(Object.keys(select).sort()).toEqual(
      ["avatarUrl", "currentStreak", "id", "maxStreak", "name", "username"].sort(),
    );
  });
});
