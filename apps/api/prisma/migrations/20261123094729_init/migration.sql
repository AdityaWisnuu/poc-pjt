-- CreateEnum
CREATE TYPE "TransactionStatus" AS ENUM ('CREATED', 'SELLING_USDC', 'BUYING_IDRX', 'SENDING_IDRX', 'AWAITING_RECEIPT', 'PAYING_MERCHANT', 'SUCCESS', 'FAILED', 'NEEDS_REVIEW');

-- CreateEnum
CREATE TYPE "SettlementMode" AS ENUM ('SIMULATE', 'LIVE');

-- CreateTable
CREATE TABLE "quotes" (
    "id" UUID NOT NULL,
    "qr_payload" TEXT NOT NULL,
    "merchant_name" TEXT NOT NULL,
    "merchant_city" TEXT NOT NULL,
    "amount_idr" INTEGER NOT NULL,
    "buy_idr" INTEGER NOT NULL,
    "usdc_amount" DECIMAL(20,8) NOT NULL,
    "usdc_idr_bid" DECIMAL(20,4) NOT NULL,
    "idrx_idr_ask" DECIMAL(20,6) NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "quotes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transactions" (
    "id" UUID NOT NULL,
    "quote_id" UUID NOT NULL,
    "mode" "SettlementMode" NOT NULL,
    "status" "TransactionStatus" NOT NULL DEFAULT 'CREATED',
    "merchant_name" TEXT NOT NULL,
    "merchant_city" TEXT NOT NULL,
    "amount_idr" INTEGER NOT NULL,
    "usdc_planned" DECIMAL(20,8) NOT NULL,
    "usdc_sold" DECIMAL(20,8),
    "idr_proceeds" INTEGER,
    "idrx_bought" DECIMAL(20,2),
    "idrx_sent" DECIMAL(20,2),
    "fee_idr" INTEGER NOT NULL DEFAULT 0,
    "sell_client_order_id" TEXT NOT NULL,
    "buy_client_order_id" TEXT NOT NULL,
    "withdraw_request_id" TEXT NOT NULL,
    "failure_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transaction_histories" (
    "id" UUID NOT NULL,
    "transaction_id" UUID NOT NULL,
    "from_status" "TransactionStatus",
    "to_status" "TransactionStatus" NOT NULL,
    "actor" TEXT NOT NULL,
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "transaction_histories_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "transactions_quote_id_key" ON "transactions"("quote_id");

-- CreateIndex
CREATE UNIQUE INDEX "transactions_sell_client_order_id_key" ON "transactions"("sell_client_order_id");

-- CreateIndex
CREATE UNIQUE INDEX "transactions_buy_client_order_id_key" ON "transactions"("buy_client_order_id");

-- CreateIndex
CREATE UNIQUE INDEX "transactions_withdraw_request_id_key" ON "transactions"("withdraw_request_id");

-- CreateIndex
CREATE INDEX "transactions_status_idx" ON "transactions"("status");

-- CreateIndex
CREATE INDEX "transactions_created_at_idx" ON "transactions"("created_at");

-- CreateIndex
CREATE INDEX "transaction_histories_transaction_id_created_at_idx" ON "transaction_histories"("transaction_id", "created_at");

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_quote_id_fkey" FOREIGN KEY ("quote_id") REFERENCES "quotes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transaction_histories" ADD CONSTRAINT "transaction_histories_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "transactions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
