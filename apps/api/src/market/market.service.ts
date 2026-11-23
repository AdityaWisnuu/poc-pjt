import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { Level } from '../quote/quote-math';

export interface Depth {
  bids: Level[];
  asks: Level[];
}

const CACHE_MS = 2000;

@Injectable()
export class MarketService {
  private readonly cache = new Map<string, { at: number; depth: Depth }>();

  async depth(pair: 'usdcidr' | 'idxidr'): Promise<Depth> {
    const hit = this.cache.get(pair);
    if (hit && Date.now() - hit.at < CACHE_MS) return hit.depth;

    try {
      const response = await fetch(`https://indodax.com/api/depth/${pair}`, {
        headers: { 'User-Agent': 'Mozilla/5.0 (compatible; poc-pjt)' },
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const body = (await response.json()) as { buy: Level[]; sell: Level[] };
      if (!body.buy?.length || !body.sell?.length) {
        throw new Error('order book kosong');
      }
      const depth = { bids: body.buy, asks: body.sell };
      this.cache.set(pair, { at: Date.now(), depth });
      return depth;
    } catch {
      throw new ServiceUnavailableException('Kurs sedang tidak tersedia');
    }
  }
}
