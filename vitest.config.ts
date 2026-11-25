import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
    // Zera os mocks (vi.fn) entre um teste e outro, para um teste nunca depender do anterior
    mockReset: true,
    coverage: {
      provider: "v8",
      include: ["src/**/*.ts"],
      exclude: ["src/server.ts", "src/lib/prisma.ts", "src/**/*.d.ts"],
      reporter: ["text", "html"],
    },
  },
});
