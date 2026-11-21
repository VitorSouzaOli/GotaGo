import { beforeEach, describe, expect, it, vi } from "vitest";
import { prismaMock } from "../helpers/prisma-mock.js";

vi.mock("../../src/lib/prisma.js", async () => {
  const { prismaMock } = await import("../helpers/prisma-mock.js");
  return { prisma: prismaMock };
});

import { checkAndUnlockAchievements } from "../../src/utils/check-achieviments.js";

const USER_ID = "user-1";

function makeUser(overrides: {
  logs?: number;
  streak?: number;
  unlocked?: string[];
} = {}) {
  return {
    id: USER_ID,
    currentStreak: overrides.streak ?? 0,
    waterLogs: Array.from({ length: overrides.logs ?? 0 }, (_, i) => ({ id: `log-${i}` })),
    achievements: (overrides.unlocked ?? []).map((code) => ({ achievement: { code } })),
  };
}

beforeEach(() => {
  // upsert devolve a conquista com o mesmo conteúdo que o código tentou criar
  prismaMock.achievement.upsert.mockImplementation(async ({ where, create }) => ({
    id: `ach-${where.code}`,
    ...create,
  }));
  prismaMock.userAchievement.create.mockResolvedValue({});
});

describe("checkAndUnlockAchievements", () => {
  describe("sem nada a desbloquear", () => {
    it("devolve lista vazia quando o usuário não existe", async () => {
      prismaMock.user.findUnique.mockResolvedValue(null);

      await expect(checkAndUnlockAchievements(USER_ID)).resolves.toEqual([]);
      expect(prismaMock.achievement.upsert).not.toHaveBeenCalled();
      expect(prismaMock.userAchievement.create).not.toHaveBeenCalled();
    });

    it("devolve vazio para usuário sem registros e sem streak", async () => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser());

      await expect(checkAndUnlockAchievements(USER_ID)).resolves.toEqual([]);
      expect(prismaMock.userAchievement.create).not.toHaveBeenCalled();
    });

    it("não desbloqueia streak com apenas 2 dias", async () => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser({ logs: 5, streak: 2, unlocked: ["FIRST_DROP"] }));

      await expect(checkAndUnlockAchievements(USER_ID)).resolves.toEqual([]);
    });

    it("não repete conquistas já desbloqueadas", async () => {
      prismaMock.user.findUnique.mockResolvedValue(
        makeUser({
          logs: 10,
          streak: 30,
          unlocked: ["FIRST_DROP", "STREAK_3_DAYS", "STREAK_7_DAYS", "STREAK_30_DAYS"],
        }),
      );

      await expect(checkAndUnlockAchievements(USER_ID)).resolves.toEqual([]);
      expect(prismaMock.achievement.upsert).not.toHaveBeenCalled();
      expect(prismaMock.userAchievement.create).not.toHaveBeenCalled();
    });
  });

  describe("Primeira Gota (FIRST_DROP)", () => {
    it("desbloqueia com o primeiro registro de água", async () => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser({ logs: 1 }));

      await expect(checkAndUnlockAchievements(USER_ID)).resolves.toEqual(["Primeira Gota"]);
    });

    it("grava a conquista no catálogo e o desbloqueio do usuário", async () => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser({ logs: 1 }));

      await checkAndUnlockAchievements(USER_ID);

      expect(prismaMock.achievement.upsert).toHaveBeenCalledWith({
        where: { code: "FIRST_DROP" },
        update: {},
        create: {
          code: "FIRST_DROP",
          name: "Primeira Gota",
          description: "Registaste o teu primeiro consumo de água no GotaGo!",
        },
      });
      expect(prismaMock.userAchievement.create).toHaveBeenCalledWith({
        data: { userId: USER_ID, achievementId: "ach-FIRST_DROP" },
      });
    });

    it("desbloqueia também com vários registros", async () => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser({ logs: 50 }));

      await expect(checkAndUnlockAchievements(USER_ID)).resolves.toEqual(["Primeira Gota"]);
    });

    it("exige ao menos 1 registro: com 0 registros, só a conquista de streak é liberada", async () => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser({ logs: 0, streak: 3 }));

      await expect(checkAndUnlockAchievements(USER_ID)).resolves.toEqual(["3 Dias Hidratado"]);
    });
  });

  describe("conquistas de streak", () => {
    it.each([
      [3, ["Primeira Gota", "3 Dias Hidratado"]],
      [6, ["Primeira Gota", "3 Dias Hidratado"]],
      [7, ["Primeira Gota", "3 Dias Hidratado", "Semana Perfeita"]],
      [29, ["Primeira Gota", "3 Dias Hidratado", "Semana Perfeita"]],
      [30, ["Primeira Gota", "3 Dias Hidratado", "Semana Perfeita", "Mestre da Hidratação"]],
      [100, ["Primeira Gota", "3 Dias Hidratado", "Semana Perfeita", "Mestre da Hidratação"]],
    ])("com streak %s desbloqueia %j (na ordem das regras)", async (streak, expected) => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser({ logs: 1, streak }));

      await expect(checkAndUnlockAchievements(USER_ID)).resolves.toEqual(expected);
      expect(prismaMock.userAchievement.create).toHaveBeenCalledTimes(expected.length);
    });

    it("usa o código certo de cada conquista", async () => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser({ logs: 1, streak: 30 }));

      await checkAndUnlockAchievements(USER_ID);

      const codes = prismaMock.achievement.upsert.mock.calls.map(([arg]) => arg.where.code);
      expect(codes).toEqual(["FIRST_DROP", "STREAK_3_DAYS", "STREAK_7_DAYS", "STREAK_30_DAYS"]);
    });
  });

  describe("desbloqueio parcial", () => {
    it("só desbloqueia o que ainda falta", async () => {
      prismaMock.user.findUnique.mockResolvedValue(
        makeUser({ logs: 4, streak: 7, unlocked: ["STREAK_3_DAYS"] }),
      );

      await expect(checkAndUnlockAchievements(USER_ID)).resolves.toEqual([
        "Primeira Gota",
        "Semana Perfeita",
      ]);
      expect(prismaMock.userAchievement.create).toHaveBeenCalledTimes(2);
    });

    it("não desbloqueia de novo quando só a primeira já existia", async () => {
      prismaMock.user.findUnique.mockResolvedValue(
        makeUser({ logs: 4, streak: 3, unlocked: ["FIRST_DROP"] }),
      );

      await expect(checkAndUnlockAchievements(USER_ID)).resolves.toEqual(["3 Dias Hidratado"]);
    });
  });

  describe("consulta e falhas", () => {
    it("busca o usuário com registros e conquistas já desbloqueadas", async () => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser());

      await checkAndUnlockAchievements(USER_ID);

      expect(prismaMock.user.findUnique).toHaveBeenCalledWith({
        where: { id: USER_ID },
        include: {
          waterLogs: true,
          achievements: { include: { achievement: true } },
        },
      });
    });

    it("propaga o erro quando o banco falha ao criar a conquista", async () => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser({ logs: 1 }));
      prismaMock.achievement.upsert.mockRejectedValue(new Error("banco fora do ar"));

      await expect(checkAndUnlockAchievements(USER_ID)).rejects.toThrow("banco fora do ar");
    });

    it("propaga o erro quando o banco falha ao registrar o desbloqueio", async () => {
      prismaMock.user.findUnique.mockResolvedValue(makeUser({ logs: 1 }));
      prismaMock.userAchievement.create.mockRejectedValue(new Error("violação de unicidade"));

      await expect(checkAndUnlockAchievements(USER_ID)).rejects.toThrow("violação de unicidade");
    });
  });
});
