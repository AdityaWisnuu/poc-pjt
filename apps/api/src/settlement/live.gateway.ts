import { Injectable } from '@nestjs/common';
import Decimal from 'decimal.js';
import { AppConfig } from '../config';
import {
  Balances,
  BuyResult,
  ConvertibleAsset,
  SellResult,
  SettlementGateway,
  TransferResult,
  UnknownOutcomeError,
} from './gateway';
import { IndodaxClient } from './indodax.client';

interface Fill {
  qty: string;
  quoteQty: string;
  commission: string;
}

interface OrderResponse {
  fullOrderId?: string;
  orderId?: number;
}

const pause = (ms: number) => new Promise((done) => setTimeout(done, ms));
const sum = (fills: Fill[], key: keyof Fill) =>
  fills.reduce((total, fill) => total.plus(fill[key]), new Decimal(0));

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
    return { USDC: free('USDC'), USDT: free('USDT'), IDRX: free('IDX') };
  }

  async sellAsset(
    asset: ConvertibleAsset,
    quantity: Decimal,
    clientOrderId: string,
  ): Promise<SellResult> {
    const order = await this.indodax.post<OrderResponse>('/api/v2/order', {
      symbol: `${asset}IDR`,
      side: 'SELL',
      type: 'MARKET',
      quantity: quantity.toFixed(8),
      newClientOrderId: clientOrderId,
    });
    const fills = await this.waitForFills(
      `${asset.toLowerCase()}idr`,
      clientOrderId,
    );
    const assetSold = sum(fills, 'qty');
    const gross = sum(fills, 'quoteQty');
    const feeIdr = sum(fills, 'commission').ceil().toNumber();
    const grossIdr = gross.floor().toNumber();
    return {
      reference: order.fullOrderId ?? String(order.orderId),
      assetSold,
      avgPrice: gross.div(assetSold),
      grossIdr,
      idrNet: grossIdr - feeIdr,
      feeIdr,
    };
  }

  async buyIdrx(idr: number, clientOrderId: string): Promise<BuyResult> {
    const order = await this.indodax.post<OrderResponse>('/api/v2/order', {
      symbol: 'IDXIDR',
      side: 'BUY',
      type: 'MARKET',
      quoteOrderQty: String(idr),
      newClientOrderId: clientOrderId,
    });
    const fills = await this.waitForFills('idxidr', clientOrderId);
    const idrxBought = sum(fills, 'qty');
    return {
      reference: order.fullOrderId ?? String(order.orderId),
      idrxBought,
      avgPrice: sum(fills, 'quoteQty').div(idrxBought),
      feeIdr: sum(fills, 'commission').ceil().toNumber(),
    };
  }

  async sendIdrx(amount: Decimal, requestId: string): Promise<TransferResult> {
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

    const withdrawal = await this.indodax.post<{
      id?: string;
      transactionFee?: string;
    }>('/api/v2/capital/withdraw/apply', {
      coin: 'IDX',
      amount: amount.toFixed(0),
      withdrawOrderId: requestId,
      withdrawMethod: 'username',
      withdrawUsername: username,
    });
    return {
      reference: withdrawal.id ?? requestId,
      feeIdrx: withdrawal.transactionFee ?? '0',
    };
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
