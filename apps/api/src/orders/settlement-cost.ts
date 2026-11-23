/**
 * True conversion cost: value in, minus the rupiah buffer and IDRX that stay
 * in the account. Null until both conversions have settled.
 */
export function settlementCost(evidence: Record<string, any>) {
  const { sell, buy } = evidence;
  if (!sell || !buy) return null;
  const leftoverIdr = Number(sell.netIdr) - Number(buy.idrSpent);
  const idr = Number(sell.grossIdr) - leftoverIdr - Number(buy.idrx);
  const base = Number(sell.grossIdr) - leftoverIdr;
  return { idr, bps: Math.round((idr / base) * 10000) };
}
