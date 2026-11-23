import Decimal from 'decimal.js';

export type Level = [string, string];

/** Measured from two real Indodax swaps on 2026-11-23. */
export const SELL_FEE = new Decimal('0.0041');
export const BUY_FEE = new Decimal('0.0021');
export const USDC_BUFFER = new Decimal('0.005');
export const MIN_ORDER_IDR = 10000;
export const MIN_PAYMENT_IDR = 11000;

export class InsufficientLiquidityError extends Error {}

/** IDR needed to market-buy `targetIdrx` net of fee, walking the asks. */
export function idrToBuyIdrx(asks: Level[], targetIdrx: number): number {
  let remaining = new Decimal(targetIdrx).div(new Decimal(1).minus(BUY_FEE));
  let cost = new Decimal(0);
  for (const [price, size] of asks) {
    const take = Decimal.min(remaining, size);
    cost = cost.plus(take.times(price));
    remaining = remaining.minus(take);
    // +2 rupiah absorbs Indodax rounding its fee up on each fill.
    if (remaining.lte(0)) return cost.ceil().plus(2).toNumber();
  }
  throw new InsufficientLiquidityError('Likuiditas IDRX tidak cukup');
}

/** Stablecoin to market-sell so net proceeds cover `idr`, walking the bids. */
export function assetToSellForIdr(bids: Level[], idr: number): Decimal {
  let remaining = new Decimal(idr).div(new Decimal(1).minus(SELL_FEE));
  let quantity = new Decimal(0);
  for (const [price, size] of bids) {
    const levelValue = new Decimal(size).times(price);
    if (levelValue.gte(remaining)) {
      quantity = quantity.plus(remaining.div(price));
      return quantity
        .times(new Decimal(1).plus(USDC_BUFFER))
        .toDecimalPlaces(8, Decimal.ROUND_UP);
    }
    quantity = quantity.plus(size);
    remaining = remaining.minus(levelValue);
  }
  throw new InsufficientLiquidityError('Likuiditas aset tidak cukup');
}
