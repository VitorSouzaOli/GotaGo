import { FastifyInstance } from "fastify";
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

import { checkAndUnlockAchievements } from "../../src/utils/check-achieviments.js";
import { waterLogRoutes } from "../../src/routes/water-logs-route.js";

const LOG_ID = "1b2c3d4e-5f6a-4b7c-8d9e-0f1a2b3c4d5e";
const NOW = new Date(2026, 10, 21, 15, 0);
const at = (day: number, hour: number) => new Date(2026, 10, day, hour);

let app: FastifyInstance;

const send = (method: "GET" | "PATCH" | "DELETE", url: string, payload?: object) =>
  app.inject({ method, url, payload, headers: authHeader(app) });

beforeEach(async () => {
  vi.useFakeTimers({ toFake: ["Date"] });
  vi.setSystemTime(NOW);
  app = await buildApp(waterLogRoutes);
  prismaMock.user.findUnique.mockResolvedValue({
    id: USER_ID,
    dailyGoal: 2000,
    currentStreak: 1,
    maxStreak: 3,
  });
  prismaMock.waterLog.findFirst.mockResolvedValue({ id: LOG_ID, createdAt: at(21, 9) });
  prismaMock.waterLog.update.mockImplementation(async ({ data }) => ({ id: LOG_ID, ...data }));
  prismaMock.waterLog.findMany.mockResolvedValue([]);
  vi.mocked(checkAndUnlockAchievements).mockResolvedValue([]);
});

afterEach(async () => {
  vi.useRealTimers();
  await app.close();
});

describe("PATCH /water-logs/:id", () => {
  const url = `/water-logs/${LOG_ID}`;

  it("altera o registro do próprio usuário e recalcula a sequência", async () => {
    const res = await send("PATCH", url, { amount: 400 });

    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ waterLog: { amount: 400 }, currentStreak: 0 });
    expect(prismaMock.waterLog.findFirst).toHaveBeenCalledWith({
      where: { id: LOG_ID, userId: USER_ID },
    });
    expect(prismaMock.user.update).toHaveBeenCalled();
  });

  it("desbloqueia na hora a conquista completada pela correção", async () => {
    vi.mocked(checkAndUnlockAchievements).mockResolvedValue(["3 Dias Hidratado"]);

    const res = await send("PATCH", url, { amount: 2000 });

    expect(res.json().newAchievements).toEqual(["3 Dias Hidratado"]);
    expect(checkAndUnlockAchievements).toHaveBeenCalledWith(USER_ID);
  });

  it("responde 404 para registro inexistente ou de outra pessoa", async () => {
    prismaMock.waterLog.findFirst.mockResolvedValue(null);

    const res = await send("PATCH", url, { amount: 400 });

    expect(res.statusCode).toBe(404);
    expect(prismaMock.waterLog.update).not.toHaveBeenCalled();
  });

  it.each([
    ["horário no futuro", { createdAt: at(21, 18).toISOString() }],
    ["outro dia", { createdAt: at(19, 9).toISOString() }],
    ["corpo vazio", {}],
    ["quantidade zero", { amount: 0 }],
  ])("rejeita %s", async (_nome, payload) => {
    const res = await send("PATCH", url, payload);

    expect(res.statusCode).toBe(400);
    expect(prismaMock.waterLog.update).not.toHaveBeenCalled();
  });
});

describe("DELETE /water-logs/:id", () => {
  const url = `/water-logs/${LOG_ID}`;

  it("exclui só se for do dono do token", async () => {
    prismaMock.waterLog.deleteMany.mockResolvedValue({ count: 1 });

    const res = await send("DELETE", url);

    expect(res.statusCode).toBe(204);
    expect(prismaMock.waterLog.deleteMany).toHaveBeenCalledWith({
      where: { id: LOG_ID, userId: USER_ID },
    });
  });

  it("responde 404 quando nada é excluído", async () => {
    prismaMock.waterLog.deleteMany.mockResolvedValue({ count: 0 });

    expect((await send("DELETE", url)).statusCode).toBe(404);
    expect(prismaMock.user.update).not.toHaveBeenCalled();
  });

  it("responde 404 se a conta não existe mais", async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);

    expect((await send("DELETE", url)).statusCode).toBe(404);
  });
});

describe("GET /users/:userId/water-logs", () => {
  it("lista os últimos N dias do próprio usuário", async () => {
    const res = await send("GET", `/users/${USER_ID}/water-logs?days=3`);

    expect(res.json()).toEqual({ waterLogs: [] });
    expect(prismaMock.waterLog.findMany.mock.calls[0][0].where).toEqual({
      userId: USER_ID,
      createdAt: { gte: new Date(2026, 10, 19) },
    });
  });

  it("nega os dados de outra pessoa", async () => {
    const res = await send("GET", `/users/${OTHER_USER_ID}/water-logs`);

    expect(res.statusCode).toBe(403);
    expect(prismaMock.waterLog.findMany).not.toHaveBeenCalled();
  });

  it("limita o período a 90 dias", async () => {
    expect((await send("GET", `/users/${USER_ID}/water-logs?days=91`)).statusCode).toBe(400);
  });
});

describe("GET /water-logs/today", () => {
  it("soma os registros do dia", async () => {
    prismaMock.waterLog.findMany.mockResolvedValue([{ amount: 1500 }, { amount: 500 }]);

    const res = await send("GET", "/water-logs/today");

    expect(res.json()).toMatchObject({ date: "2026-11-21", totalToday: 2000, goalReached: true });
  });

  it("responde 404 se a conta não existe mais", async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);

    expect((await send("GET", "/water-logs/today")).statusCode).toBe(404);
  });
});

describe("GET /water-logs/history", () => {
  it("devolve um item por dia, do mais recente ao mais antigo, com a meta de cada dia", async () => {
    prismaMock.waterLog.findMany.mockResolvedValue([
      { amount: 2000, dailyGoal: 2000, createdAt: at(19, 10) },
      { amount: 2000, dailyGoal: 2500, createdAt: at(21, 10) },
    ]);

    const res = await send("GET", "/water-logs/history?days=3");

    expect(res.json().history).toEqual([
      { date: "2026-11-21", total: 2000, goalReached: false },
      { date: "2026-11-20", total: 0, goalReached: false },
      { date: "2026-11-19", total: 2000, goalReached: true },
    ]);
  });

  it("responde 404 se a conta não existe mais", async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);

    expect((await send("GET", "/water-logs/history")).statusCode).toBe(404);
  });
});
