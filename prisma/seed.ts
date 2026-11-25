import { PrismaClient } from "@prisma/client";
import { ACHIEVEMENTS } from "../src/utils/achievements-catalog.js";
import { hashPassword } from "../src/lib/password.js";

const prisma = new PrismaClient();

async function main() {
  // upsert = "cria se não existir, senão atualiza": rodar o seed várias vezes não duplica nada
  for (const { code, name, description } of ACHIEVEMENTS) {
    await prisma.achievement.upsert({
      where: { code },
      update: { name, description },
      create: { code, name, description },
    });
  }

  // Usuário de teste para desenvolvimento local (peso 70kg -> meta de 2450ml)
  const user = await prisma.user.upsert({
    where: { email: "teste@gotago.dev" },
    update: {},
    create: {
      name: "Usuário Teste",
      username: "teste",
      email: "teste@gotago.dev",
      passwordHash: await hashPassword("123456"),
      weight: 70,
      dailyGoal: 2450,
    },
  });

  // Liga de teste com o usuário de teste como dono e primeiro membro
  await prisma.league.upsert({
    where: { code: "GOTA-TEST" },
    update: {},
    create: {
      name: "Liga de Teste",
      description: "Liga criada pelo seed para testes locais",
      code: "GOTA-TEST",
      ownerId: user.id,
      members: { create: { userId: user.id } },
    },
  });

  console.log("🌱 Seed concluído: conquistas, usuário e liga de teste criados.");
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
