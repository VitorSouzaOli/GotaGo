import { hash } from "bcryptjs";
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
import { userRoutes } from "../../src/routes/user-routes.js";

const stored = {
  id: USER_ID,
  name: "Maria",
  username: "maria",
  email: "maria@gotago.dev",
  passwordHash: "",
  avatarUrl: null,
  weight: 70,
  dailyGoal: 2000,
  currentStreak: 0,
  maxStreak: 0,
};

let app: FastifyInstance;

const send = (method: "PATCH" | "DELETE", url: string, payload?: object) =>
  app.inject({ method, url, payload, headers: authHeader(app) });

beforeEach(async () => {
  app = await buildApp(userRoutes);
  prismaMock.user.findUnique.mockResolvedValue({
    ...stored,
    passwordHash: await hash("atual123", 4),
  });
  prismaMock.user.update.mockImplementation(async ({ data }) => ({ ...stored, ...data }));
  prismaMock.waterLog.findMany.mockResolvedValue([]);
  vi.mocked(checkAndUnlockAchievements).mockResolvedValue([]);
});

afterEach(async () => {
  await app.close();
});

describe.each([
  ["PATCH", ""],
  ["PATCH", "/password"],
  ["DELETE", ""],
] as const)("%s /users/:id%s", (method, suffix) => {
  it("só permite mexer na própria conta", async () => {
    const res = await send(method, `/users/${OTHER_USER_ID}${suffix}`, { name: "Outro" });

    expect(res.statusCode).toBe(403);
    expect(prismaMock.user.update).not.toHaveBeenCalled();
    expect(prismaMock.user.deleteMany).not.toHaveBeenCalled();
  });
});

describe("PATCH /users/:id", () => {
  it("altera o nome sem recalcular sequências", async () => {
    const res = await send("PATCH", `/users/${USER_ID}`, { name: "Maria S." });

    expect(res.statusCode).toBe(200);
    expect(res.json().user.name).toBe("Maria S.");
    expect(res.body).not.toContain("passwordHash");
    expect(prismaMock.waterLog.updateMany).not.toHaveBeenCalled();
    expect(checkAndUnlockAchievements).not.toHaveBeenCalled();
  });

  it("aplica a nova meta aos registros de hoje e recalcula a sequência", async () => {
    prismaMock.waterLog.findMany.mockResolvedValue([
      { amount: 3000, dailyGoal: 3000, createdAt: new Date() },
    ]);

    const res = await send("PATCH", `/users/${USER_ID}`, { dailyGoal: 3000 });

    expect(res.json().user).toMatchObject({ dailyGoal: 3000, currentStreak: 1, maxStreak: 1 });
    expect(prismaMock.waterLog.updateMany.mock.calls[0][0].data).toEqual({ dailyGoal: 3000 });
  });

  it("desbloqueia na hora a conquista completada pela nova meta", async () => {
    vi.mocked(checkAndUnlockAchievements).mockResolvedValue(["3 Dias Hidratado"]);

    const res = await send("PATCH", `/users/${USER_ID}`, { dailyGoal: 1500 });

    expect(res.json().newAchievements).toEqual(["3 Dias Hidratado"]);
    expect(checkAndUnlockAchievements).toHaveBeenCalledWith(USER_ID);
  });

  it("não aceita e-mail, streak ou outros campos protegidos", async () => {
    const res = await send("PATCH", `/users/${USER_ID}`, { currentStreak: 999 });

    expect(res.statusCode).toBe(400);
    expect(prismaMock.user.update).not.toHaveBeenCalled();
  });

  it.each([
    ["meta baixa", { dailyGoal: 999 }],
    ["peso negativo", { weight: -1 }],
    ["corpo vazio", {}],
  ])("rejeita %s", async (_nome, payload) => {
    expect((await send("PATCH", `/users/${USER_ID}`, payload)).statusCode).toBe(400);
  });
});

describe("PATCH /users/:id/password", () => {
  const url = `/users/${USER_ID}/password`;

  it("troca a senha quando a atual confere", async () => {
    const res = await send("PATCH", url, { currentPassword: "atual123", newPassword: "nova1234" });

    expect(res.statusCode).toBe(204);
    expect(prismaMock.user.update.mock.calls[0][0].data.passwordHash).not.toBe("nova1234");
  });

  it("recusa a senha atual errada com a mensagem que o app traduz", async () => {
    const res = await send("PATCH", url, { currentPassword: "errada", newPassword: "nova1234" });

    expect(res.statusCode).toBe(400);
    expect(res.json()).toEqual({ error: "Invalid credentials" });
    expect(prismaMock.user.update).not.toHaveBeenCalled();
  });
});

describe("DELETE /users/:id", () => {
  it("passa as ligas ao membro mais antigo antes de excluir a conta", async () => {
    prismaMock.league.findMany.mockResolvedValue([
      { id: "liga-com-gente", members: [{ userId: OTHER_USER_ID }] },
      { id: "liga-vazia", members: [] },
    ]);
    prismaMock.user.deleteMany.mockResolvedValue({ count: 1 });

    const res = await send("DELETE", `/users/${USER_ID}`);

    expect(res.statusCode).toBe(204);
    expect(prismaMock.league.update).toHaveBeenCalledTimes(1);
    expect(prismaMock.league.update).toHaveBeenCalledWith({
      where: { id: "liga-com-gente" },
      data: { ownerId: OTHER_USER_ID },
    });
    expect(prismaMock.user.deleteMany).toHaveBeenCalledWith({ where: { id: USER_ID } });
  });

  it("responde 404 se a conta já não existe", async () => {
    prismaMock.league.findMany.mockResolvedValue([]);
    prismaMock.user.deleteMany.mockResolvedValue({ count: 0 });

    expect((await send("DELETE", `/users/${USER_ID}`)).statusCode).toBe(404);
  });
});
