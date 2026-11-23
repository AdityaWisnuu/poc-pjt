-- AlterTable
ALTER TABLE "transactions" ADD COLUMN     "evidence" JSONB NOT NULL DEFAULT '{}';
