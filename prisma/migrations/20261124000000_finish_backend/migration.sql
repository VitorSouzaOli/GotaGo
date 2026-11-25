-- AlterTable
ALTER TABLE "water_logs" ADD COLUMN     "daily_goal" INTEGER;

-- Registros antigos passam a guardar a meta atual do dono (não havia como mudá-la antes)
UPDATE "water_logs" AS w SET "daily_goal" = u."daily_goal" FROM "users" AS u WHERE u."id" = w."user_id";

-- CreateTable
CREATE TABLE "password_reset_tokens" (
    "id" TEXT NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "user_id" TEXT NOT NULL,

    CONSTRAINT "password_reset_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "password_reset_tokens_token_hash_key" ON "password_reset_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "password_reset_tokens_user_id_idx" ON "password_reset_tokens"("user_id");

-- CreateIndex
CREATE INDEX "water_logs_user_id_created_at_idx" ON "water_logs"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "leagues_owner_id_idx" ON "leagues"("owner_id");

-- CreateIndex
CREATE INDEX "league_members_user_id_idx" ON "league_members"("user_id");

-- AddForeignKey
ALTER TABLE "password_reset_tokens" ADD CONSTRAINT "password_reset_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- E-mails passam a ser gravados em minúsculas (pula os que colidiriam com outra conta)
UPDATE "users" AS u SET "email" = lower(u."email")
WHERE u."email" <> lower(u."email")
  AND NOT EXISTS (SELECT 1 FROM "users" AS o WHERE o."id" <> u."id" AND lower(o."email") = lower(u."email"));

-- Catálogo de conquistas (dados fixos do sistema, não dependem do seed)
INSERT INTO "achievements" ("id", "code", "name", "description") VALUES
  (gen_random_uuid()::text, 'FIRST_DROP', 'Primeira Gota', 'Registaste o teu primeiro consumo de água no GotaGo!'),
  (gen_random_uuid()::text, 'STREAK_3_DAYS', '3 Dias Hidratado', 'Atingiste a meta diária por 3 dias consecutivos!'),
  (gen_random_uuid()::text, 'STREAK_7_DAYS', 'Semana Perfeita', 'Atingiste a meta diária por 7 dias consecutivos!'),
  (gen_random_uuid()::text, 'STREAK_30_DAYS', 'Mestre da Hidratação', 'Mantiveste a tua meta por 30 dias seguidos!')
ON CONFLICT ("code") DO NOTHING;
