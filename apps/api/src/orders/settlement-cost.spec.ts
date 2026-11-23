import { settlementCost } from './settlement-cost';

describe('settlementCost', () => {
  it('matches the real 2 USDC swap on Indodax (62 bps)', () => {
    expect(
      settlementCost({
        sell: { grossIdr: 36808, netIdr: 36656 },
        buy: { idrSpent: 36656, idrx: '36580' },
      }),
    ).toEqual({ idr: 228, bps: 62 });
  });

  it('excludes the unspent rupiah buffer from cost', () => {
    const cost = settlementCost({
      sell: { grossIdr: 25300, netIdr: 25196 },
      buy: { idrSpent: 25055, idrx: '25002' },
    });
    expect(cost?.idr).toBe(157);
    expect(cost?.bps).toBe(62);
  });

  it('is null before both conversions finish', () => {
    expect(settlementCost({ sell: { grossIdr: 1, netIdr: 1 } })).toBeNull();
  });
});
