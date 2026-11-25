import { describe, expect, it } from "vitest";
import { calculateStreaks, summarizeByDay } from "../../src/utils/streak.js";

const NOW = new Date(2026, 10, 21, 15, 0);
const GOAL = 2000;

// um registro `daysAgo` dias antes de NOW
const log = (daysAgo: number, amount = GOAL, dailyGoal: number | null = GOAL, hour = 12) => ({
  amount,
  dailyGoal,
  createdAt: new Date(2026, 10, 21 - daysAgo, hour),
});

describe("summarizeByDay", () => {
  it("soma os registros do mesmo dia", () => {
    const days = summarizeByDay([log(0, 800), log(0, 1200)], GOAL);

    expect(days.get("2026-11-21")).toEqual({ total: 2000, goal: GOAL, goalReached: true });
  });

  it("usa a meta do registro mais recente do dia, em qualquer ordem de entrada", () => {
    const days = summarizeByDay([log(0, 1000, 3000, 18), log(0, 1000, 2000, 8)], GOAL);

    expect(days.get("2026-11-21")).toMatchObject({ goal: 3000, goalReached: false });
  });

  it("usa a meta atual quando o registro antigo não guardou meta", () => {
    const days = summarizeByDay([log(0, 2000, null)], 2500);

    expect(days.get("2026-11-21")).toMatchObject({ goal: 2500, goalReached: false });
  });
});

describe("calculateStreaks", () => {
  it.each([
    ["sem registros", [], 0, 0],
    ["só hoje", [log(0)], 1, 1],
    ["ontem e hoje ainda em andamento", [log(1), log(0, 100)], 1, 1],
    ["três dias seguidos até hoje", [log(2), log(1), log(0)], 3, 3],
    ["sequência quebrada anteontem", [log(3), log(1), log(0)], 2, 2],
    ["último dia batido foi anteontem", [log(2), log(3)], 0, 2],
    ["recorde antigo maior que a atual", [log(9), log(8), log(7), log(0)], 1, 3],
    ["dia abaixo da meta não conta", [log(1, 1999), log(0)], 1, 1],
  ])("%s", (_nome, logs, currentStreak, maxStreak) => {
    expect(calculateStreaks(logs, GOAL, NOW)).toEqual({ currentStreak, maxStreak });
  });

  it("atravessa a virada de mês", () => {
    const logs = [new Date(2026, 9, 31, 12), new Date(2026, 10, 1, 12)].map((createdAt) => ({
      amount: GOAL,
      dailyGoal: GOAL,
      createdAt,
    }));

    expect(calculateStreaks(logs, GOAL, new Date(2026, 10, 1, 20))).toEqual({
      currentStreak: 2,
      maxStreak: 2,
    });
  });

  it("subir a meta hoje não apaga os dias que cumpriram a meta antiga", () => {
    const logs = [log(1, 2000, 2000), log(0, 2000, 3000)];

    expect(calculateStreaks(logs, 3000, NOW)).toEqual({ currentStreak: 1, maxStreak: 1 });
  });
});
