import { vi } from "vitest";

// "Prisma falso": cada método é um vi.fn() que o teste programa com o resultado que quiser.
// Assim os testes rodam sem banco de dados.
export const prismaMock = {
  // Executa a transação direto sobre o próprio mock (forma de função ou de lista)
  $transaction: vi.fn(async (input: any): Promise<any> =>
    typeof input === "function" ? input(prismaMock) : Promise.all(input),
  ),
  $queryRaw: vi.fn(),
  user: {
    findUnique: vi.fn(),
    findFirst: vi.fn(),
    findMany: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    updateMany: vi.fn(),
    deleteMany: vi.fn(),
  },
  waterLog: {
    create: vi.fn(),
    aggregate: vi.fn(),
    findMany: vi.fn(),
    findFirst: vi.fn(),
    update: vi.fn(),
    updateMany: vi.fn(),
    deleteMany: vi.fn(),
  },
  league: {
    findUnique: vi.fn(),
    findMany: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  },
  leagueMember: {
    findUnique: vi.fn(),
    findFirst: vi.fn(),
    findMany: vi.fn(),
    create: vi.fn(),
    deleteMany: vi.fn(),
  },
  achievement: {
    findMany: vi.fn(),
    upsert: vi.fn(),
  },
  userAchievement: {
    findMany: vi.fn(),
    createMany: vi.fn(),
  },
  passwordResetToken: {
    findUnique: vi.fn(),
    create: vi.fn(),
    deleteMany: vi.fn(),
  },
};
