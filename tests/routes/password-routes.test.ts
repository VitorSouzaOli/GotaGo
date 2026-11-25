import { createHash } from "node:crypto";
import { compare } from "bcryptjs";
import { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { buildApp, USER_ID } from "../helpers/build-app.js";
import { prismaMock } from "../helpers/prisma-mock.js";

vi.mock("../../src/lib/prisma.js", async () => {
  const { prismaMock } = await import("../helpers/prisma-mock.js");
  return { prisma: prismaMock };
});
vi.mock("../../src/lib/mailer.js", () => ({ sendPasswordResetEmail: vi.fn() }));

import { sendPasswordResetEmail } from "../../src/lib/mailer.js";
import { passwordRoutes } from "../../src/routes/password-routes.js";

let app: FastifyInstance;
const post = (url: string, payload: object) => app.inject({ method: "POST", url, payload });
const sha256 = (value: string) => createHash("sha256").update(value).digest("hex");

beforeEach(async () => {
  app = await buildApp(passwordRoutes);
});

afterEach(async () => {
  await app.close();
});

describe("POST /passwords/forgot", () => {
  it("envia o link e grava somente o hash do token", async () => {
    prismaMock.user.findUnique.mockResolvedValue({ id: USER_ID, email: "maria@gotago.dev" });

    const res = await post("/passwords/forgot", { email: " Maria@GotaGo.dev " });

    expect(res.statusCode).toBe(202);
    const link = vi.mocked(sendPasswordResetEmail).mock.calls[0][1];
    const token = link.split("#token=")[1];
    expect(link).toContain("/passwords/reset#token=");
    expect(prismaMock.passwordResetToken.create.mock.calls[0][0].data.tokenHash).toBe(sha256(token));
    expect(prismaMock.passwordResetToken.deleteMany).toHaveBeenCalledWith({
      where: { userId: USER_ID },
    });
    expect(res.body).not.toContain(token);
  });

  it("responde igual para e-mail sem conta, sem enviar nada", async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);

    const res = await post("/passwords/forgot", { email: "ninguem@gotago.dev" });

    expect(res.statusCode).toBe(202);
    expect(sendPasswordResetEmail).not.toHaveBeenCalled();
  });
});

describe("GET /passwords/reset", () => {
  it("serve a página com a política de segurança", async () => {
    const res = await app.inject({ method: "GET", url: "/passwords/reset" });

    expect(res.headers["content-type"]).toContain("text/html");
    expect(res.headers["content-security-policy"]).toContain("default-src 'none'");
    expect(res.headers["cache-control"]).toBe("no-store");
  });
});

describe("POST /passwords/reset", () => {
  const body = { token: "token-do-email", password: "novaSenha1" };
  const record = (expiresAt: Date) => ({ id: "t-1", userId: USER_ID, expiresAt });
  const future = () => new Date(Date.now() + 60_000);

  it("troca a senha e consome o token", async () => {
    prismaMock.passwordResetToken.findUnique.mockResolvedValue(record(future()));
    prismaMock.passwordResetToken.deleteMany.mockResolvedValue({ count: 1 });

    const res = await post("/passwords/reset", body);

    expect(res.statusCode).toBe(204);
    expect(prismaMock.passwordResetToken.findUnique).toHaveBeenCalledWith({
      where: { tokenHash: sha256(body.token) },
    });
    const { data } = prismaMock.user.update.mock.calls[0][0];
    await expect(compare(body.password, data.passwordHash)).resolves.toBe(true);
  });

  it.each([
    ["inexistente", null, 1],
    ["expirado", record(new Date(Date.now() - 1000)), 1],
    ["já usado por outra requisição", record(new Date(Date.now() + 60_000)), 0],
  ])("recusa token %s", async (_nome, found, count) => {
    prismaMock.passwordResetToken.findUnique.mockResolvedValue(found);
    prismaMock.passwordResetToken.deleteMany.mockResolvedValue({ count });

    const res = await post("/passwords/reset", body);

    expect(res.statusCode).toBe(400);
    expect(prismaMock.user.update).not.toHaveBeenCalled();
  });

  it("recusa senha curta", async () => {
    const res = await post("/passwords/reset", { ...body, password: "123" });

    expect(res.statusCode).toBe(400);
    expect(prismaMock.passwordResetToken.findUnique).not.toHaveBeenCalled();
  });
});
