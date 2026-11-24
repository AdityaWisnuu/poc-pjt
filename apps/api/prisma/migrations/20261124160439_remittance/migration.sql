-- CreateEnum
CREATE TYPE "RemitDirection" AS ENUM ('INBOUND', 'OUTBOUND');

-- CreateEnum
CREATE TYPE "RemitStatus" AS ENUM ('CREATED', 'SCREENING', 'COLLECTING', 'SENDING_ASSET', 'CONVERTING', 'PAYING_OUT', 'SUCCESS', 'FAILED', 'NEEDS_REVIEW');

-- CreateTable
CREATE TABLE "remit_quotes" (
    "id" UUID NOT NULL,
    "direction" "RemitDirection" NOT NULL,
    "funding_currency" TEXT NOT NULL,
    "send_amount" DECIMAL(20,8) NOT NULL,
    "usdc_amount" DECIMAL(20,8) NOT NULL,
    "receive_amount" DECIMAL(20,2) NOT NULL,
    "receive_currency" TEXT NOT NULL,
    "pricing" JSONB NOT NULL,
    "sender" JSONB NOT NULL,
    "recipient" JSONB NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "remit_quotes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "remittances" (
    "id" UUID NOT NULL,
    "quote_id" UUID NOT NULL,
    "direction" "RemitDirection" NOT NULL,
    "mode" "SettlementMode" NOT NULL,
    "status" "RemitStatus" NOT NULL DEFAULT 'CREATED',
    "funding_currency" TEXT NOT NULL,
    "send_amount" DECIMAL(20,8) NOT NULL,
    "usdc_amount" DECIMAL(20,8) NOT NULL,
    "receive_amount" DECIMAL(20,2) NOT NULL,
    "receive_currency" TEXT NOT NULL,
    "sender" JSONB NOT NULL,
    "recipient" JSONB NOT NULL,
    "withdraw_request_id" TEXT NOT NULL,
    "failure_reason" TEXT,
    "evidence" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "remittances_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "remit_histories" (
    "id" UUID NOT NULL,
    "remittance_id" UUID NOT NULL,
    "from_status" "RemitStatus",
    "to_status" "RemitStatus" NOT NULL,
    "actor" TEXT NOT NULL,
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "remit_histories_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "remittances_quote_id_key" ON "remittances"("quote_id");

-- CreateIndex
CREATE UNIQUE INDEX "remittances_withdraw_request_id_key" ON "remittances"("withdraw_request_id");

-- CreateIndex
CREATE INDEX "remittances_status_idx" ON "remittances"("status");

-- CreateIndex
CREATE INDEX "remittances_created_at_idx" ON "remittances"("created_at");

-- CreateIndex
CREATE INDEX "remit_histories_remittance_id_created_at_idx" ON "remit_histories"("remittance_id", "created_at");

-- AddForeignKey
ALTER TABLE "remittances" ADD CONSTRAINT "remittances_quote_id_fkey" FOREIGN KEY ("quote_id") REFERENCES "remit_quotes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "remit_histories" ADD CONSTRAINT "remit_histories_remittance_id_fkey" FOREIGN KEY ("remittance_id") REFERENCES "remittances"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
