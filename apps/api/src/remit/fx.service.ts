import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import Decimal from 'decimal.js';

const CACHE_MS = 10 * 60_000;
export const FX_SOURCE = 'exchangerate-api.com (kurs referensi harian)';

/** Daily reference rates, units of each currency per 1 USD. */
@Injectable()
export class FxService {
  private cache: {
    at: number;
    rates: Record<string, number>;
    updated: string;
  } | null = null;

  async perUsd(currency: string): Promise<{ rate: Decimal; updated: string }> {
    if (!this.cache || Date.now() - this.cache.at > CACHE_MS) {
      try {
        const response = await fetch('https://open.er-api.com/v6/latest/USD', {
          signal: AbortSignal.timeout(8000),
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const body = (await response.json()) as {
          result: string;
          rates: Record<string, number>;
          time_last_update_utc: string;
        };
        if (body.result !== 'success') throw new Error(body.result);
        this.cache = {
          at: Date.now(),
          rates: body.rates,
          updated: new Date(body.time_last_update_utc).toISOString(),
        };
      } catch {
        if (!this.cache) {
          throw new ServiceUnavailableException(
            'Kurs valas sedang tidak tersedia',
          );
        }
      }
    }
    const rate = this.cache.rates[currency];
    if (!rate)
      throw new ServiceUnavailableException(`Kurs ${currency} tidak tersedia`);
    return { rate: new Decimal(rate), updated: this.cache.updated };
  }
}
