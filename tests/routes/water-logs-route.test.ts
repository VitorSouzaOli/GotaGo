import Fastify, { FastifyInstance } from "fastify";
import jwt from "@fastify/jwt";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { authHeader, buildApp, OTHER_USER_ID, USER_ID } from "../helpers/build-app.js";
import { prismaMock } from "../helpers/prisma-mock.js";

vi.mock("../../src/lib/prisma.js", async () => {
  const { prismaMock } = await import("../helpers/prisma-mock.js");
  return { prisma: prismaMock };
});
vi.mock("../../src/utils/check-achieviments.js", () => ({
  checkAndUnlockAchievements: vi.fn(),
}));

import { waterLogRoutes } from "../../src/routes/water-logs-route.js";
import { checkAndUnlockAchievements } from "../../src/utils/check-achieviments.js";

const DAILY_GOAL = 2000;
let app: FastifyInstance;

const addWater = (payload?: unknown, headers = authHeader(app)) =>
  app.inject({ method: "POST", url: "/water-logs", headers, payload: payload as object });

// Programa o banco para "depois deste registro, o total de hoje é X"
function totalTodayIs(total: number | null) {
  prismaMock.waterLog.aggregate.mockResolvedValue({ _sum: { amount: total } });
}

beforeEach(async () => {
  app = await buildApp(waterLogRoutes);

  prismaMock.user.findUnique.mockResolvedValue({
    id: USER_ID,
    dailyGoal: DAILY_GOAL,
    currentStreak: 2,
    maxStreak: 5,
  });
  prismaMock.user.update.mockResolvedValue({});
  prismaMock.waterLog.findMany.mockResolvedValue([]);
  prismaMock.waterLog.create.mockImplementation(async ({ data }) => ({
    id: "log-1",
    createdAt: new Date("2026-11-21T15:00:00.000Z"),
    ...data,
  }));
  totalTodayIs(500);
  vi.mocked(checkAndUnlockAchievements).mockResolvedValue([]);
});

afterEach(async () => {
  vi.useRealTimers();
  await app.close();
});

describe("POST /water-logs", () => {
  describe("autenticação", () => {
    it("responde 401 sem token", async () => {
      const res = await addWater({ amount: 300 }, {} as never);

      expect(res.statusCode).toBe(401);
      expect(res.json()).toEqual({ error: "Token inválido ou ausente." });
      expect(prismaMock.waterLog.create).not.toHaveBeenCalled();
    });

    it("responde 401 com token malformado", async () => {
      const res = await addWater({ amount: 300 }, { authorization: "Bearer abc.def.ghi" });

      expect(res.statusCode).toBe(401);
      expect(prismaMock.waterLog.create).not.toHaveBeenCalled();
    });

    it("responde 401 sem o prefixo Bearer", async () => {
      const token = app.jwt.sign({ sub: USER_ID });

      const res = await addWater({ amount: 300 }, { authorization: token });

      expect(res.statusCode).toBe(401);
    });

    it("responde 401 com token assinado por outra chave", async () => {
      const intruder = Fastify();
      intruder.register(jwt, { secret: "chave-do-invasor" });
      await intruder.ready();
      const forged = intruder.jwt.sign({ sub: USER_ID });

      const res = await addWater({ amount: 300 }, { authorization: `Bearer ${forged}` });

      expect(res.statusCode).toBe(401);
      expect(prismaMock.waterLog.create).not.toHaveBeenCalled();
    });

    it("responde 401 com token expirado", async () => {
      const expired = app.jwt.sign({ sub: USER_ID }, { expiresIn: "1ms" });
      await new Promise((resolve) => setTimeout(resolve, 20));

      const res = await addWater({ amount: 300 }, { authorization: `Bearer ${expired}` });

      expect(res.statusCode).toBe(401);
    });
  });

  describe("validação", () => {
    it.each([
      ["zero", { amount: 0 }],
      ["negativo", { amount: -100 }],
      ["texto", { amount: "300" }],
      ["nulo", { amount: null }],
      ["ausente", {}],
    ])("rejeita quantidade %s com 400", async (_nome, payload) => {
      const res = await addWater(payload);

      expect(res.statusCode).toBe(400);
      expect(res.json().issues[0].field).toBe("amount");
      expect(prismaMock.user.findUnique).not.toHaveBeenCalled();
      expect(prismaMock.waterLog.create).not.toHaveBeenCalled();
    });

    it("rejeita requisição sem corpo", async () => {
      const res = await app.inject({ method: "POST", url: "/water-logs", headers: authHeader(app) });

      expect(res.statusCode).toBe(400);
    });
  });

  describe("usuário vem do token", () => {
    it("registra para o dono do token e ignora um userId enviado no corpo", async () => {
      const res = await addWater({ amount: 300, userId: OTHER_USER_ID });

      expect(res.statusCode).toBe(201);
      expect(prismaMock.user.findUnique).toHaveBeenCalledWith({ where: { id: USER_ID } });
      expect(prismaMock.waterLog.create).toHaveBeenCalledWith({
        data: { userId: USER_ID, amount: 300, dailyGoal: DAILY_GOAL },
      });
    });

    it("responde 404 quando o dono do token não existe mais", async () => {
      prismaMock.user.findUnique.mockResolvedValue(null);

      const res = await addWater({ amount: 300 });

      expect(res.statusCode).toBe(404);
      expect(res.json()).toEqual({ error: "Utilizador não encontrado." });
      expect(prismaMock.waterLog.create).not.toHaveBeenCalled();
    });
  });

  describe("registro e total do dia", () => {
    it("responde 201 com o registro, o total, a meta e as flags", async () => {
      totalTodayIs(800);

      const res = await addWater({ amount: 300 });

      expect(res.statusCode).toBe(201);
      expect(res.json()).toMatchObject({
        waterLog: { id: "log-1", userId: USER_ID, amount: 300 },
        totalToday: 800,
        dailyGoal: DAILY_GOAL,
        goalReached: false,
        streakUpdated: false,
        newAchievements: [],
      });
      expect(res.json().warning).toBeUndefined();
    });

    it("soma o dia de 00:00 até a meia-noite seguinte, no horário do servidor", async () => {
      vi.useFakeTimers({ toFake: ["Date"] });
      vi.setSystemTime(new Date(2026, 10, 21, 15, 30, 12));

      await addWater({ amount: 300 });

      const { where, _sum } = prismaMock.waterLog.aggregate.mock.calls[0][0];
      expect(_sum).toEqual({ amount: true });
      expect(where.userId).toBe(USER_ID);
      expect(where.createdAt.gte).toEqual(new Date(2026, 10, 21));
      expect(where.createdAt.lt).toEqual(new Date(2026, 10, 22));
    });

    it("trata soma nula (sem registros) como 0", async () => {
      totalTodayIs(null);

      const res = await addWater({ amount: 300 });

      expect(res.json().totalToday).toBe(0);
      expect(res.json().goalReached).toBe(false);
    });
  });

  describe("alerta de hiper-hidratação (> 4000ml)", () => {
    it("não avisa com exatamente 4000ml", async () => {
      totalTodayIs(4000);

      const res = await addWater({ amount: 500 });

      expect(res.statusCode).toBe(201);
      expect(res.json().warning).toBeUndefined();
    });

    it("avisa com 4001ml, mas mantém o registro salvo", async () => {
      totalTodayIs(4001);

      const res = await addWater({ amount: 500 });

      expect(res.statusCode).toBe(201);
      expect(res.json().warning).toContain("4000ml");
      expect(prismaMock.waterLog.create).toHaveBeenCalledTimes(1);
    });

    it("continua avisando em totais muito altos", async () => {
      totalTodayIs(9000);

      const res = await addWater({ amount: 1000 });

      expect(res.json().warning).toBeDefined();
      expect(res.json().totalToday).toBe(9000);
    });
  });

  describe("streak (dias seguidos batendo a meta)", () => {
    // um registro `daysAgo` dias antes de hoje
    const logOn = (daysAgo: number, amount = DAILY_GOAL, dailyGoal = DAILY_GOAL) => {
      const createdAt = new Date();
      createdAt.setHours(12, 0, 0, 0);
      createdAt.setDate(createdAt.getDate() - daysAgo);
      return { amount, createdAt, dailyGoal };
    };

    it("calcula a sequência pelos registros e grava no usuário", async () => {
      prismaMock.waterLog.findMany.mockResolvedValue([logOn(2), logOn(1), logOn(0)]);
      totalTodayIs(2000);

      const res = await addWater({ amount: 500 });

      expect(res.json()).toMatchObject({ currentStreak: 3, maxStreak: 3, streakUpdated: true });
      expect(prismaMock.user.update).toHaveBeenCalledWith({
        where: { id: USER_ID },
        data: { currentStreak: 3, maxStreak: 3 },
      });
    });

    it("trava a linha do usuário antes de gravar", async () => {
      await addWater({ amount: 300 });

      expect(prismaMock.$queryRaw.mock.invocationCallOrder[0]).toBeLessThan(
        prismaMock.waterLog.create.mock.invocationCallOrder[0],
      );
    });

    it.each([
      ["ao cruzar a meta neste registro", 2100, 500, true],
      ["com exatamente o valor da meta", DAILY_GOAL, 500, true],
      ["com um único registro grande", 2500, 2500, true],
      ["com 1ml a menos que a meta", DAILY_GOAL - 1, 500, false],
      ["com a meta já batida antes", 2600, 300, false],
    ])("define streakUpdated %s", async (_nome, total, amount, expected) => {
      totalTodayIs(total);

      const res = await addWater({ amount });

      expect(res.json().streakUpdated).toBe(expected);
    });

    it("respeita a meta personalizada de cada usuário", async () => {
      prismaMock.user.findUnique.mockResolvedValue({ id: USER_ID, dailyGoal: 3500 });
      totalTodayIs(3000);

      const res = await addWater({ amount: 500 });

      expect(res.json()).toMatchObject({ dailyGoal: 3500, goalReached: false });
    });

    it.each([
      ["decimal", 250.5],
      ["acima do máximo", 5001],
    ])("rejeita quantidade %s com 400", async (_nome, amount) => {
      const res = await addWater({ amount });

      expect(res.statusCode).toBe(400);
      expect(prismaMock.waterLog.create).not.toHaveBeenCalled();
    });
  });

  describe("conquistas", () => {
    it("devolve as conquistas desbloqueadas neste registro", async () => {
      vi.mocked(checkAndUnlockAchievements).mockResolvedValue(["Primeira Gota"]);

      const res = await addWater({ amount: 300 });

      expect(res.json().newAchievements).toEqual(["Primeira Gota"]);
      expect(checkAndUnlockAchievements).toHaveBeenCalledWith(USER_ID);
    });

    it("verifica as conquistas mesmo sem mudança de streak", async () => {
      await addWater({ amount: 300 });

      expect(checkAndUnlockAchievements).toHaveBeenCalledTimes(1);
    });
  });

  describe("falhas inesperadas", () => {
    it("responde 500 e não segue adiante se o banco falhar ao gravar", async () => {
      prismaMock.waterLog.create.mockRejectedValue(new Error("disco cheio"));

      const res = await addWater({ amount: 300 });

      expect(res.statusCode).toBe(500);
      expect(res.json()).toEqual({ error: "Erro interno do servidor." });
      expect(prismaMock.waterLog.aggregate).not.toHaveBeenCalled();
      expect(checkAndUnlockAchievements).not.toHaveBeenCalled();
    });
  });
});
