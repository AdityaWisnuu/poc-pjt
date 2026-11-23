import Decimal from 'decimal.js';
import {
  idrToBuyIdrx,
  InsufficientLiquidityError,
  Level,
  SELL_FEE,
  assetToSellForIdr,
} from './quote-math';

describe('quote math', () => {
  it('grosses up the IDR needed for an exact IDRX amount', () => {
    const asks: Level[] = [['1', '1000000']];
    expect(idrToBuyIdrx(asks, 36522)).toBe(36601);
  });

  it('walks ask levels when the best level is thin', () => {
    const asks: Level[] = [
      ['1', '5000'],
      ['1.01', '100000'],
    ];
    expect(idrToBuyIdrx(asks, 10000)).toBeGreaterThan(10021);
  });

  it('sells enough USDC to net the target after fee and buffer', () => {
    const bids: Level[] = [['18000', '100']];
    const usdc = assetToSellForIdr(bids, 36000);
    const net = usdc.times(18000).times(new Decimal(1).minus(SELL_FEE));
    expect(net.gte(36000)).toBe(true);
    expect(net.lt(36400)).toBe(true);
  });

  it('walks bid levels', () => {
    const bids: Level[] = [
      ['18000', '1'],
      ['17900', '100'],
    ];
    const flat = assetToSellForIdr([['18000', '100']], 36000);
    expect(assetToSellForIdr(bids, 36000).gt(flat)).toBe(true);
  });

  it('throws when the book cannot fill', () => {
    expect(() => idrToBuyIdrx([['1', '10']], 1000)).toThrow(
      InsufficientLiquidityError,
    );
    expect(() => assetToSellForIdr([['18000', '0.001']], 1000)).toThrow(
      InsufficientLiquidityError,
    );
  });
});
