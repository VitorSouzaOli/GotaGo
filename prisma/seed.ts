import { PrismaClient } from "@prisma/client";
import { hash } from "bcryptjs";

const prisma = new PrismaClient();

// As mesmas conquistas que o utils/check-achieviments.ts desbloqueia
const achievements = [
  {
    code: "FIRST_DROP",
    name: "Primeira Gota",
    description: "Registaste o teu primeiro consumo de água no GotaGo!",
  },
  {
    code: "STREAK_3_DAYS",
    name: "3 Dias Hidratado",
    description: "Atingiste a meta diária por 3 dias consecutivos!",
  },
  {
    code: "STREAK_7_DAYS",
    name: "Semana Perfeita",
    description: "Atingiste a meta diária por 7 dias consecutivos!",
  },
  {
    code: "STREAK_30_DAYS",
    name: "Mestre da Hidratação",
    description: "Mantiveste a tua meta por 30 dias seguidos!",
  },
];

async function main() {
  // upsert = "cria se não existir, senão atualiza": rodar o seed várias vezes não duplica nada
  for (const achievement of achievements) {
    await prisma.achievement.upsert({
      where: { code: achievement.code },
      update: { name: achievement.name, description: achievement.description },
      create: achievement,
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
      passwordHash: await hash("123456", 6),
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
