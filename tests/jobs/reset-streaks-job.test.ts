import { FastifyBaseLogger } from "fastify";
import { afterEach, describe, expect, it, vi } from "vitest";
import { prismaMock } from "../helpers/prisma-mock.js";

vi.mock("../../src/lib/prisma.js", async () => {
  const { prismaMock } = await import("../helpers/prisma-mock.js");
  return { prisma: prismaMock };
});

import { resetBrokenStreaks, startResetStreaksJob } from "../../src/jobs/reset-streaks-job.js";

const NOW = new Date(2026, 10, 21, 0, 0, 5);
const user = (id: string, currentStreak = 4) => ({ id, dailyGoal: 2000, currentStreak });
const log = (userId: string, day: number, amount = 2000) => ({
  userId,
  amount,
  dailyGoal: 2000,
  createdAt: new Date(2026, 10, day, 0, 0, 1),
});

afterEach(() => {
  vi.useRealTimers();
});

describe("resetBrokenStreaks", () => {
  it("não consulta registros quando ninguém tem sequência", async () => {
    prismaMock.user.findMany.mockResolvedValue([]);

    await expect(resetBrokenStreaks(NOW)).resolves.toBe(0);
    expect(prismaMock.waterLog.findMany).not.toHaveBeenCalled();
  });

  it("zera quem falhou ontem, recomeça em 1 quem já bateu hoje e mantém quem cumpriu", async () => {
    prismaMock.user.findMany.mockResolvedValue([
      user("cumpriu"),
      user("falhou"),
      user("recomecou"),
      user("ja-corrigido", 1),
    ]);
    prismaMock.waterLog.findMany.mockResolvedValue([
      log("cumpriu", 20),
      log("falhou", 20, 500),
      log("recomecou", 21),
      log("ja-corrigido", 21),
    ]);
    prismaMock.user.updateMany.mockImplementation(async ({ where }) => ({
      count: where.id.in.length,
    }));

    await expect(resetBrokenStreaks(NOW)).resolves.toBe(2);
    expect(prismaMock.user.updateMany.mock.calls.map(([arg]) => arg)).toEqual([
      { where: { id: { in: ["falhou"] } }, data: { currentStreak: 0 } },
      { where: { id: { in: ["recomecou"] } }, data: { currentStreak: 1 } },
    ]);
  });
});

describe("startResetStreaksJob", () => {
  const log = { info: vi.fn(), error: vi.fn() } as unknown as FastifyBaseLogger;

  it("roda ao iniciar, de novo após a meia-noite, e para quando cancelado", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 10, 21, 23, 59, 0));
    prismaMock.user.findMany.mockResolvedValue([]);

    const stop = startResetStreaksJob(log);
    await vi.advanceTimersByTimeAsync(0);
    expect(prismaMock.user.findMany).toHaveBeenCalledTimes(1);

    await vi.advanceTimersByTimeAsync(66_000);
    expect(prismaMock.user.findMany).toHaveBeenCalledTimes(2);

    stop();
    await vi.advanceTimersByTimeAsync(48 * 60 * 60 * 1000);
    expect(prismaMock.user.findMany).toHaveBeenCalledTimes(2);
  });

  it("registra a falha sem derrubar o servidor", async () => {
    vi.useFakeTimers();
    prismaMock.user.findMany.mockRejectedValue(new Error("banco fora"));

    const stop = startResetStreaksJob(log);
    await vi.advanceTimersByTimeAsync(0);
    stop();

    expect(log.error).toHaveBeenCalled();
  });
});
