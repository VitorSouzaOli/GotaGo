import { vi } from "vitest";

// "Prisma falso": cada método é um vi.fn() que o teste programa com o resultado que quiser.
// Assim os testes rodam sem banco de dados.
export const prismaMock = {
  user: {
    findUnique: vi.fn(),
    findFirst: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
  },
  waterLog: {
    create: vi.fn(),
    aggregate: vi.fn(),
  },
  league: {
    findUnique: vi.fn(),
    create: vi.fn(),
  },
  leagueMember: {
    findUnique: vi.fn(),
    create: vi.fn(),
  },
  achievement: {
    findMany: vi.fn(),
    upsert: vi.fn(),
  },
  userAchievement: {
    findMany: vi.fn(),
    create: vi.fn(),
  },
};
