CREATE TYPE "PayAsset" AS ENUM ('USDC', 'USDT', 'IDRX');

ALTER TYPE "TransactionStatus" RENAME VALUE 'SELLING_USDC' TO 'SELLING_ASSET';

ALTER TABLE "quotes" ADD COLUMN "asset" "PayAsset" NOT NULL DEFAULT 'USDC';
ALTER TABLE "quotes" RENAME COLUMN "usdc_amount" TO "asset_amount";
ALTER TABLE "quotes" RENAME COLUMN "usdc_idr_bid" TO "asset_idr_bid";

ALTER TABLE "transactions" ADD COLUMN "asset" "PayAsset" NOT NULL DEFAULT 'USDC';
ALTER TABLE "transactions" RENAME COLUMN "usdc_planned" TO "asset_planned";
ALTER TABLE "transactions" RENAME COLUMN "usdc_sold" TO "asset_sold";
