import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AppConfig {
  constructor(private readonly env: ConfigService) {}

  /** Live needs two explicit switches, so a stray DRY_RUN=false alone moves nothing. */
  get isLive(): boolean {
    return (
      this.env.get<string>('SETTLEMENT_MODE') === 'live' &&
      this.env.get<string>('DRY_RUN') === 'false'
    );
  }

  get maxIdrPerRun(): number {
    return Number(this.env.get('MAX_IDR_PER_RUN') ?? 100000);
  }

  /** Assets the Settlement Account's callback currently authorizes. */
  get liveAssets(): string[] {
    return (this.env.get<string>('LIVE_ASSETS') ?? 'USDC')
      .split(',')
      .map((asset) => asset.trim().toUpperCase())
      .filter(Boolean);
  }

  /** Mirrors the callback's per-withdrawal cap, so the app never asks for more. */
  get maxUsdcPerTransfer(): number {
    return Number(this.env.get('MAX_USDC_PER_TRANSFER') ?? 5);
  }

  get port(): number {
    return Number(this.env.get('PORT') ?? 3000);
  }

  get simUsdcBalance(): string {
    return this.env.get<string>('SIM_USDC_BALANCE') ?? '16.0002';
  }

  get simUsdtBalance(): string {
    return this.env.get<string>('SIM_USDT_BALANCE') ?? '20';
  }

  get simIdrxBalance(): string {
    return this.env.get<string>('SIM_IDRX_BALANCE') ?? '73102';
  }

  get tunnelPort(): number {
    return Number(this.env.get('INDODAX_TUNNEL_PORT') ?? 8443);
  }

  get settlementUsername(): string {
    return this.env.get<string>('SETTLEMENT_USERNAME') ?? 'dimasriat';
  }

  get callbackBaseUrl(): string {
    return (
      this.env.get<string>('CALLBACK_BASE_URL') ??
      'https://indodax-cb.dimsky.xyz'
    );
  }

  required(name: string): string {
    const value = this.env.get<string>(name);
    if (!value) throw new Error(`${name} belum diisi`);
    return value;
  }
}
