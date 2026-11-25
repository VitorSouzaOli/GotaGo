import { hash } from "bcryptjs";
import { FastifyInstance } from "fastify";
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { buildApp, USER_ID } from "../helpers/build-app.js";
import { prismaMock } from "../helpers/prisma-mock.js";

vi.mock("../../src/lib/prisma.js", async () => {
  const { prismaMock } = await import("../helpers/prisma-mock.js");
  return { prisma: prismaMock };
});

import { sessionRoutes } from "../../src/routes/session-routes.js";

const PASSWORD = "segredo123";
let passwordHash: string;
let app: FastifyInstance;

const login = (payload?: unknown) =>
  app.inject({ method: "POST", url: "/sessions", payload: payload as object });

const storedUser = () => ({
  id: USER_ID,
  name: "Maria Silva",
  username: "maria",
  email: "maria@gotago.dev",
  passwordHash,
  avatarUrl: null,
  weight: 80,
  dailyGoal: 2800,
  currentStreak: 4,
  maxStreak: 9,
});

beforeAll(async () => {
  // custo baixo só para os testes rodarem rápido
  passwordHash = await hash(PASSWORD, 4);
});

beforeEach(async () => {
  app = await buildApp(sessionRoutes);
});

afterEach(async () => {
  await app.close();
});

describe("POST /sessions", () => {
  describe("login com sucesso", () => {
    beforeEach(() => {
      prismaMock.user.findFirst.mockResolvedValue(storedUser());
    });

    it("responde 200 com o token e os dados do usuário", async () => {
      const res = await login({ login: "maria@gotago.dev", password: PASSWORD });

      expect(res.statusCode).toBe(200);
      expect(typeof res.json().token).toBe("string");
      expect(res.json().user).toEqual({
        id: USER_ID,
        name: "Maria Silva",
        username: "maria",
        email: "maria@gotago.dev",
        avatarUrl: null,
        weight: 80,
        dailyGoal: 2800,
        currentStreak: 4,
        maxStreak: 9,
      });
    });

    it("nunca devolve o hash da senha", async () => {
      const res = await login({ login: "maria@gotago.dev", password: PASSWORD });

      expect(res.body).not.toContain("passwordHash");
      expect(res.body).not.toContain(passwordHash);
    });

    it("gera um token que identifica o usuário (sub) e vale 7 dias", async () => {
      const res = await login({ login: "maria", password: PASSWORD });

      const payload = app.jwt.verify<{ sub: string; iat: number; exp: number }>(res.json().token);
      expect(payload.sub).toBe(USER_ID);
      expect(payload.exp - payload.iat).toBe(7 * 24 * 60 * 60);
    });

    it("busca por e-mail OU username", async () => {
      await login({ login: "maria@gotago.dev", password: PASSWORD });

      expect(prismaMock.user.findFirst).toHaveBeenCalledWith({
        where: { OR: [{ email: "maria@gotago.dev" }, { username: "maria@gotago.dev" }] },
      });
    });

    it("trata o username sem diferenciar maiúsculas de minúsculas", async () => {
      await login({ login: "MARIA", password: PASSWORD });

      const where = prismaMock.user.findFirst.mock.calls[0][0].where;
      expect(where.OR[1]).toEqual({ username: "maria" });
    });

    it("a senha diferencia maiúsculas de minúsculas", async () => {
      const res = await login({ login: "maria", password: PASSWORD.toUpperCase() });

      expect(res.statusCode).toBe(400);
    });
  });

  describe("credenciais inválidas", () => {
    it("responde 400 quando o usuário não existe", async () => {
      prismaMock.user.findFirst.mockResolvedValue(null);

      const res = await login({ login: "ninguem", password: PASSWORD });

      expect(res.statusCode).toBe(400);
      expect(res.json()).toEqual({ error: "Invalid credentials" });
      expect(res.json().token).toBeUndefined();
    });

    it("responde 400 quando a senha está errada", async () => {
      prismaMock.user.findFirst.mockResolvedValue(storedUser());

      const res = await login({ login: "maria", password: "senha-errada" });

      expect(res.statusCode).toBe(400);
      expect(res.json()).toEqual({ error: "Invalid credentials" });
      expect(res.json().token).toBeUndefined();
    });

    it("usa a mesma resposta para usuário inexistente e senha errada (não revela quem existe)", async () => {
      prismaMock.user.findFirst.mockResolvedValueOnce(null);
      const semUsuario = await login({ login: "ninguem", password: PASSWORD });

      prismaMock.user.findFirst.mockResolvedValueOnce(storedUser());
      const senhaErrada = await login({ login: "maria", password: "errada" });

      expect(semUsuario.statusCode).toBe(senhaErrada.statusCode);
      expect(semUsuario.body).toBe(senhaErrada.body);
    });
  });

  describe("validação dos dados", () => {
    it.each([
      ["login vazio", { login: "", password: PASSWORD }, "login"],
      ["login ausente", { password: PASSWORD }, "login"],
      ["senha vazia", { login: "maria", password: "" }, "password"],
      ["senha ausente", { login: "maria" }, "password"],
      ["login como número", { login: 123, password: PASSWORD }, "login"],
    ])("rejeita %s com 400", async (_nome, payload, field) => {
      const res = await login(payload);

      expect(res.statusCode).toBe(400);
      expect(res.json().issues.map((i: { field: string }) => i.field)).toContain(field);
      expect(prismaMock.user.findFirst).not.toHaveBeenCalled();
    });

    it("rejeita requisição sem corpo", async () => {
      const res = await app.inject({ method: "POST", url: "/sessions" });

      expect(res.statusCode).toBe(400);
    });
  });

  describe("falhas inesperadas", () => {
    it("responde 500 genérico quando o banco falha", async () => {
      prismaMock.user.findFirst.mockRejectedValue(new Error("timeout do banco"));

      const res = await login({ login: "maria", password: PASSWORD });

      expect(res.statusCode).toBe(500);
      expect(res.json()).toEqual({ error: "Erro interno do servidor." });
    });
  });
});
