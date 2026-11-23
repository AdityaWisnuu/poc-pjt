import type { PayAsset } from '@prisma/client';
import Decimal from 'decimal.js';

export const SETTLEMENT_GATEWAY = Symbol('SETTLEMENT_GATEWAY');

/** Stablecoins that must be converted before settlement. IDRX settles directly. */
export type ConvertibleAsset = Exclude<PayAsset, 'IDRX'>;

/** The request may or may not have executed. Never retry; a human must check. */
export class UnknownOutcomeError extends Error {}

export type Balances = Record<PayAsset, Decimal>;

export interface SellResult {
  reference: string;
  assetSold: Decimal;
  avgPrice: Decimal;
  grossIdr: number;
  idrNet: number;
  feeIdr: number;
}

export interface BuyResult {
  reference: string;
  idrxBought: Decimal;
  avgPrice: Decimal;
  feeIdr: number;
}

export interface TransferResult {
  reference: string;
  feeIdrx: string;
}

export interface SettlementGateway {
  balances(): Promise<Balances>;
  sellAsset(
    asset: ConvertibleAsset,
    quantity: Decimal,
    clientOrderId: string,
  ): Promise<SellResult>;
  buyIdrx(idr: number, clientOrderId: string): Promise<BuyResult>;
  sendIdrx(amount: Decimal, requestId: string): Promise<TransferResult>;
}
