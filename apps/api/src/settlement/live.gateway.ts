import { Injectable } from '@nestjs/common';
import Decimal from 'decimal.js';
import { AppConfig } from '../config';
import {
  Balances,
  BuyResult,
  SellResult,
  SettlementGateway,
  UnknownOutcomeError,
} from './gateway';
import { IndodaxClient } from './indodax.client';

interface Fill {
  qty: string;
  quoteQty: string;
  commission: string;
}

const pause = (ms: number) => new Promise((done) => setTimeout(done, ms));

@Injectable()
export class LiveGateway implements SettlementGateway {
  constructor(
    private readonly config: AppConfig,
    private readonly indodax: IndodaxClient,
  ) {}

  async balances(): Promise<Balances> {
    const account = await this.indodax.get<{
      balances: { asset: string; free: string }[];
    }>('/api/v2/account');
    const free = (asset: string) =>
      new Decimal(
        account.balances.find((b) => b.asset.toUpperCase() === asset)?.free ?? 0,
      );
    return { usdc: free('USDC'), idrx: free('IDX') };
  }

  async sellUsdc(quantity: Decimal, clientOrderId: string): Promise<SellResult> {
    await this.indodax.post('/api/v2/order', {
      symbol: 'USDCIDR',
      side: 'SELL',
      type: 'MARKET',
      quantity: quantity.toFixed(8),
      newClientOrderId: clientOrderId,
    });
    const fills = await this.waitForFills('usdcidr', clientOrderId);
    const gross = fills.reduce((sum, f) => sum.plus(f.quoteQty), new Decimal(0));
    const feeIdr = fills
      .reduce((sum, f) => sum.plus(f.commission), new Decimal(0))
      .ceil()
      .toNumber();
    return {
      usdcSold: fills.reduce((sum, f) => sum.plus(f.qty), new Decimal(0)),
      idrNet: gross.floor().toNumber() - feeIdr,
      feeIdr,
    };
  }

  async buyIdrx(idr: number, clientOrderId: string): Promise<BuyResult> {
    await this.indodax.post('/api/v2/order', {
      symbol: 'IDXIDR',
      side: 'BUY',
      type: 'MARKET',
      quoteOrderQty: String(idr),
      newClientOrderId: clientOrderId,
    });
    const fills = await this.waitForFills('idxidr', clientOrderId);
    return {
      idrxBought: fills.reduce((sum, f) => sum.plus(f.qty), new Decimal(0)),
      feeIdr: fills
        .reduce((sum, f) => sum.plus(f.commission), new Decimal(0))
        .ceil()
        .toNumber(),
    };
  }

  async sendIdrx(amount: Decimal, requestId: string): Promise<void> {
    const username = this.config.settlementUsername;
    const intent = await fetch(
      `${this.config.callbackBaseUrl}/internal/withdrawals`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.config.required('CALLBACK_ADMIN_TOKEN')}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          request_id: requestId,
          currency: 'idx',
          amount: amount.toFixed(0),
          username,
        }),
        signal: AbortSignal.timeout(8000),
      },
    );
    if (!intent.ok) {
      throw new Error(`Callback menolak intent (${intent.status})`);
    }

    await this.indodax.post('/api/v2/capital/withdraw/apply', {
      coin: 'IDX',
      amount: amount.toFixed(0),
      withdrawOrderId: requestId,
      withdrawMethod: 'username',
      withdrawUsername: username,
    });
  }

  private async waitForFills(symbol: string, clientOrderId: string) {
    for (let attempt = 0; attempt < 12; attempt++) {
      const result = await this.indodax.get<{ data?: Fill[] }>(
        '/api/v2/myTrades',
        { symbol, clientOrderId },
      );
      if (result.data?.length) return result.data;
      await pause(1500);
    }
    throw new UnknownOutcomeError('Order terkirim, tapi fill belum terlihat');
  }
}
