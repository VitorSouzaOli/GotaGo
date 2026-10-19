/*
  Warnings:

  - You are about to drop the column `dailyGoal` on the `users` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[username]` on the table `users` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `password_hash` to the `users` table without a default value. This is not possible if the table is not empty.
  - Added the required column `username` to the `users` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "users" DROP COLUMN "dailyGoal",
ADD COLUMN     "avatar_url" TEXT,
ADD COLUMN     "current_streak" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "daily_goal" INTEGER NOT NULL DEFAULT 2000,
ADD COLUMN     "max_streak" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "password_hash" TEXT NOT NULL,
ADD COLUMN     "username" TEXT NOT NULL,
ADD COLUMN     "weight" DOUBLE PRECISION;

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");
