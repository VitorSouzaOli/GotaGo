import { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { authHeader, buildApp, OTHER_USER_ID, USER_ID } from "../helpers/build-app.js";
import { prismaMock } from "../helpers/prisma-mock.js";

vi.mock("../../src/lib/prisma.js", async () => {
  const { prismaMock } = await import("../helpers/prisma-mock.js");
  return { prisma: prismaMock };
});

import { achievementRoutes } from "../../src/routes/achieviments-route.js";

let app: FastifyInstance;

const getAchievements = (userId: string = USER_ID, headers = authHeader(app)) =>
  app.inject({ method: "GET", url: `/users/${userId}/achievements`, headers });

const catalog = [
  { id: "a1", code: "FIRST_DROP", name: "Primeira Gota", description: "d1" },
  { id: "a2", code: "STREAK_3_DAYS", name: "3 Dias Hidratado", description: "d2" },
  { id: "a3", code: "STREAK_7_DAYS", name: "Semana Perfeita", description: "d3" },
];

beforeEach(async () => {
  app = await buildApp(achievementRoutes);

  prismaMock.user.findUnique.mockResolvedValue({ id: USER_ID });
  prismaMock.achievement.findMany.mockResolvedValue(catalog);
  prismaMock.userAchievement.findMany.mockResolvedValue([]);
});

afterEach(async () => {
  await app.close();
});

describe("GET /users/:userId/achievements", () => {
  describe("autenticação e autorização", () => {
    it("responde 401 sem token", async () => {
      const res = await getAchievements(USER_ID, {} as never);

      expect(res.statusCode).toBe(401);
      expect(prismaMock.achievement.findMany).not.toHaveBeenCalled();
    });

    it("responde 403 ao pedir as conquistas de outro usuário, sem consultar o banco", async () => {
      const res = await getAchievements(OTHER_USER_ID);

      expect(res.statusCode).toBe(403);
      expect(res.json()).toEqual({ error: "Acesso negado." });
      expect(prismaMock.user.findUnique).not.toHaveBeenCalled();
      expect(prismaMock.achievement.findMany).not.toHaveBeenCalled();
    });

    it("responde 400 com userId que não é UUID", async () => {
      const res = await getAchievements("123");

      expect(res.statusCode).toBe(400);
      expect(res.json().issues[0].field).toBe("userId");
    });

    it("responde 404 quando o dono do token não existe mais", async () => {
      prismaMock.user.findUnique.mockResolvedValue(null);

      const res = await getAchievements();

      expect(res.statusCode).toBe(404);
      expect(res.json()).toEqual({ error: "Utilizador não encontrado." });
    });
  });

  describe("conquistas", () => {
    it("lista todas como bloqueadas quando nenhuma foi desbloqueada", async () => {
      const res = await getAchievements();

      expect(res.statusCode).toBe(200);
      const list = res.json().achievements;
      expect(list).toHaveLength(3);
      expect(list.every((a: { isUnlocked: boolean }) => a.isUnlocked === false)).toBe(true);
      expect(list.every((a: { unlockedAt: unknown }) => a.unlockedAt === null)).toBe(true);
    });

    it("marca como desbloqueadas só as do usuário, com a data", async () => {
      prismaMock.userAchievement.findMany.mockResolvedValue([
        { achievementId: "a2", unlockedAt: new Date("2026-11-10T12:00:00.000Z") },
      ]);

      const res = await getAchievements();

      const byCode = Object.fromEntries(
        res.json().achievements.map((a: { code: string }) => [a.code, a]),
      );
      expect(byCode.FIRST_DROP).toMatchObject({ isUnlocked: false, unlockedAt: null });
      expect(byCode.STREAK_3_DAYS).toMatchObject({
        isUnlocked: true,
        unlockedAt: "2026-11-10T12:00:00.000Z",
      });
      expect(byCode.STREAK_7_DAYS).toMatchObject({ isUnlocked: false, unlockedAt: null });
    });

    it("marca todas como desbloqueadas quando o usuário tem todas", async () => {
      prismaMock.userAchievement.findMany.mockResolvedValue(
        catalog.map((a) => ({ achievementId: a.id, unlockedAt: new Date() })),
      );

      const res = await getAchievements();

      expect(res.json().achievements.every((a: { isUnlocked: boolean }) => a.isUnlocked)).toBe(true);
    });

    it("devolve id, código, nome e descrição de cada conquista", async () => {
      const res = await getAchievements();

      expect(res.json().achievements[0]).toEqual({
        id: "a1",
        code: "FIRST_DROP",
        name: "Primeira Gota",
        description: "d1",
        isUnlocked: false,
        unlockedAt: null,
      });
    });

    it("preserva a ordem do catálogo", async () => {
      const res = await getAchievements();

      expect(res.json().achievements.map((a: { code: string }) => a.code)).toEqual([
        "FIRST_DROP",
        "STREAK_3_DAYS",
        "STREAK_7_DAYS",
      ]);
    });

    it("devolve lista vazia quando o catálogo está vazio", async () => {
      prismaMock.achievement.findMany.mockResolvedValue([]);

      const res = await getAchievements();

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ achievements: [] });
    });

    it("consulta só os desbloqueios do próprio usuário", async () => {
      await getAchievements();

      expect(prismaMock.userAchievement.findMany).toHaveBeenCalledWith({
        where: { userId: USER_ID },
        select: { achievementId: true, unlockedAt: true },
      });
    });
  });

  it("responde 500 genérico se o banco falhar", async () => {
    prismaMock.achievement.findMany.mockRejectedValue(new Error("falha"));

    const res = await getAchievements();

    expect(res.statusCode).toBe(500);
    expect(res.json()).toEqual({ error: "Erro interno do servidor." });
  });
});
