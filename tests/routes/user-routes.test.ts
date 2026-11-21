import { compare } from "bcryptjs";
import { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { buildApp } from "../helpers/build-app.js";
import { prismaMock } from "../helpers/prisma-mock.js";

vi.mock("../../src/lib/prisma.js", async () => {
  const { prismaMock } = await import("../helpers/prisma-mock.js");
  return { prisma: prismaMock };
});

import { userRoutes } from "../../src/routes/user-routes.js";

const validBody = {
  name: "Maria Silva",
  username: "maria",
  email: "maria@gotago.dev",
  password: "segredo123",
};

let app: FastifyInstance;

const post = (payload?: unknown) =>
  app.inject({ method: "POST", url: "/users", payload: payload as object });

beforeEach(async () => {
  app = await buildApp(userRoutes);

  // Por padrão ninguém tem o mesmo e-mail/username, e o create devolve o que recebeu + defaults do banco
  prismaMock.user.findUnique.mockResolvedValue(null);
  prismaMock.user.create.mockImplementation(async ({ data }) => ({
    id: "user-id",
    currentStreak: 0,
    maxStreak: 0,
    ...data,
    // o banco devolve null (e não undefined) para colunas opcionais não preenchidas
    avatarUrl: data.avatarUrl ?? null,
    weight: data.weight ?? null,
  }));
});

afterEach(async () => {
  await app.close();
});

describe("POST /users", () => {
  describe("cadastro com sucesso", () => {
    it("cria o usuário e responde 201 com meta padrão de 2000ml sem peso", async () => {
      const res = await post(validBody);

      expect(res.statusCode).toBe(201);
      expect(res.json().user).toEqual({
        id: "user-id",
        name: "Maria Silva",
        username: "maria",
        email: "maria@gotago.dev",
        avatarUrl: null,
        weight: null,
        dailyGoal: 2000,
        currentStreak: 0,
        maxStreak: 0,
      });
      expect(res.json().warning).toBeUndefined();
    });

    it("nunca devolve a senha nem o hash", async () => {
      const res = await post(validBody);

      const text = res.body;
      expect(text).not.toContain("passwordHash");
      expect(text).not.toContain("segredo123");
    });

    it("grava o hash bcrypt da senha, nunca a senha em texto puro", async () => {
      await post(validBody);

      const { data } = prismaMock.user.create.mock.calls[0][0];
      expect(data.passwordHash).not.toBe("segredo123");
      expect(data.password).toBeUndefined();
      await expect(compare("segredo123", data.passwordHash)).resolves.toBe(true);
      await expect(compare("outra-senha", data.passwordHash)).resolves.toBe(false);
    });

    it("converte o username para minúsculas", async () => {
      await post({ ...validBody, username: "MaRiA" });

      expect(prismaMock.user.findUnique).toHaveBeenCalledWith({ where: { username: "maria" } });
      expect(prismaMock.user.create.mock.calls[0][0].data.username).toBe("maria");
    });

    it("aceita e grava avatarUrl válido", async () => {
      const res = await post({ ...validBody, avatarUrl: "https://exemplo.com/foto.png" });

      expect(res.statusCode).toBe(201);
      expect(res.json().user.avatarUrl).toBe("https://exemplo.com/foto.png");
    });

    it("aceita os valores mínimos de cada campo", async () => {
      const res = await post({ name: "Jo", username: "joa", email: "j@g.co", password: "123456" });

      expect(res.statusCode).toBe(201);
    });
  });

  describe("meta diária", () => {
    it("calcula 35ml por kg (80kg -> 2800ml) e grava o peso", async () => {
      const res = await post({ ...validBody, weightKg: 80 });

      expect(res.statusCode).toBe(201);
      expect(res.json().user.dailyGoal).toBe(2800);
      expect(res.json().user.weight).toBe(80);
      expect(res.json().warning).toBeUndefined();
    });

    it("aplica o piso de 2000ml (50kg)", async () => {
      const res = await post({ ...validBody, weightKg: 50 });

      expect(res.json().user.dailyGoal).toBe(2000);
    });

    it("avisa quando a meta calculada passa de 4000ml (120kg)", async () => {
      const res = await post({ ...validBody, weightKg: 120 });

      expect(res.statusCode).toBe(201);
      expect(res.json().user.dailyGoal).toBe(4200);
      expect(res.json().warning).toContain("4000ml");
    });

    it("usa a meta personalizada no lugar da calculada", async () => {
      const res = await post({ ...validBody, weightKg: 80, customDailyGoal: 3000 });

      expect(res.json().user.dailyGoal).toBe(3000);
      expect(res.json().warning).toBeUndefined();
    });

    it("aceita meta personalizada de exatamente 2000ml (mínimo)", async () => {
      const res = await post({ ...validBody, customDailyGoal: 2000 });

      expect(res.statusCode).toBe(201);
      expect(res.json().user.dailyGoal).toBe(2000);
    });

    it("aceita meta personalizada de exatamente 4000ml sem avisar", async () => {
      const res = await post({ ...validBody, customDailyGoal: 4000 });

      expect(res.json().user.dailyGoal).toBe(4000);
      expect(res.json().warning).toBeUndefined();
    });

    it("avisa quando a meta personalizada passa de 4000ml", async () => {
      const res = await post({ ...validBody, customDailyGoal: 4500 });

      expect(res.statusCode).toBe(201);
      expect(res.json().user.dailyGoal).toBe(4500);
      expect(res.json().warning).toContain("4000ml");
    });

    it("rejeita meta personalizada abaixo de 2000ml", async () => {
      const res = await post({ ...validBody, customDailyGoal: 1999 });

      expect(res.statusCode).toBe(400);
      expect(res.json().issues[0].field).toBe("customDailyGoal");
      expect(prismaMock.user.create).not.toHaveBeenCalled();
    });
  });

  describe("duplicidade", () => {
    it("rejeita e-mail já cadastrado com 400", async () => {
      prismaMock.user.findUnique.mockImplementation(async ({ where }) =>
        where.email ? { id: "existente" } : null,
      );

      const res = await post(validBody);

      expect(res.statusCode).toBe(400);
      expect(res.json()).toEqual({ error: "Email already exists" });
      expect(prismaMock.user.create).not.toHaveBeenCalled();
    });

    it("rejeita username já cadastrado com 400", async () => {
      prismaMock.user.findUnique.mockImplementation(async ({ where }) =>
        where.username ? { id: "existente" } : null,
      );

      const res = await post(validBody);

      expect(res.statusCode).toBe(400);
      expect(res.json()).toEqual({ error: "Username already exists" });
      expect(prismaMock.user.create).not.toHaveBeenCalled();
    });

    it("confere o e-mail antes do username", async () => {
      prismaMock.user.findUnique.mockResolvedValue({ id: "existente" });

      const res = await post(validBody);

      expect(res.json().error).toBe("Email already exists");
      expect(prismaMock.user.findUnique).toHaveBeenCalledTimes(1);
    });
  });

  describe("validação dos dados (400 com a lista de campos)", () => {
    it.each([
      ["nome curto", { name: "A" }, "name"],
      ["nome ausente", { name: undefined }, "name"],
      ["username curto", { username: "ab" }, "username"],
      ["username ausente", { username: undefined }, "username"],
      ["e-mail inválido", { email: "nao-e-email" }, "email"],
      ["e-mail ausente", { email: undefined }, "email"],
      ["senha curta", { password: "12345" }, "password"],
      ["senha ausente", { password: undefined }, "password"],
      ["peso zero", { weightKg: 0 }, "weightKg"],
      ["peso negativo", { weightKg: -5 }, "weightKg"],
      ["peso como texto", { weightKg: "80" }, "weightKg"],
      ["avatarUrl inválida", { avatarUrl: "nao-e-url" }, "avatarUrl"],
      ["meta personalizada como texto", { customDailyGoal: "3000" }, "customDailyGoal"],
    ])("rejeita %s", async (_nome, override, field) => {
      const res = await post({ ...validBody, ...override });

      expect(res.statusCode).toBe(400);
      expect(res.json().error).toBe("Dados inválidos.");
      expect(res.json().issues.map((i: { field: string }) => i.field)).toContain(field);
      expect(prismaMock.user.create).not.toHaveBeenCalled();
    });

    it("lista todos os campos inválidos de uma vez", async () => {
      const res = await post({ name: "A", username: "ab", email: "x", password: "1" });

      const fields = res.json().issues.map((i: { field: string }) => i.field);
      expect(fields).toEqual(expect.arrayContaining(["name", "username", "email", "password"]));
    });

    it("rejeita corpo vazio", async () => {
      const res = await post({});

      expect(res.statusCode).toBe(400);
      expect(res.json().issues.length).toBeGreaterThanOrEqual(4);
    });

    it("rejeita requisição sem corpo", async () => {
      const res = await app.inject({ method: "POST", url: "/users" });

      expect(res.statusCode).toBe(400);
    });

    it("rejeita JSON malformado com 400", async () => {
      const res = await app.inject({
        method: "POST",
        url: "/users",
        headers: { "content-type": "application/json" },
        payload: "{quebrado",
      });

      expect(res.statusCode).toBe(400);
      expect(res.json().error).toBeDefined();
    });

    it("não consulta o banco quando os dados são inválidos", async () => {
      await post({ ...validBody, email: "x" });

      expect(prismaMock.user.findUnique).not.toHaveBeenCalled();
    });
  });

  describe("falhas inesperadas", () => {
    it("responde 500 genérico quando o banco falha, sem vazar detalhes", async () => {
      prismaMock.user.create.mockRejectedValue(new Error("conexão recusada em 10.0.0.5"));

      const res = await post(validBody);

      expect(res.statusCode).toBe(500);
      expect(res.json()).toEqual({ error: "Erro interno do servidor." });
      expect(res.body).not.toContain("10.0.0.5");
    });
  });
});
