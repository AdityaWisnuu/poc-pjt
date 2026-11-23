import Decimal from 'decimal.js';

export const SETTLEMENT_GATEWAY = Symbol('SETTLEMENT_GATEWAY');

/** The request may or may not have executed. Never retry; a human must check. */
export class UnknownOutcomeError extends Error {}

export interface Balances {
  usdc: Decimal;
  idrx: Decimal;
}

export interface SellResult {
  usdcSold: Decimal;
  idrNet: number;
  feeIdr: number;
}

export interface BuyResult {
  idrxBought: Decimal;
  feeIdr: number;
}

export interface SettlementGateway {
  balances(): Promise<Balances>;
  sellUsdc(quantity: Decimal, clientOrderId: string): Promise<SellResult>;
  buyIdrx(idr: number, clientOrderId: string): Promise<BuyResult>;
  sendIdrx(amount: Decimal, requestId: string): Promise<void>;
}
