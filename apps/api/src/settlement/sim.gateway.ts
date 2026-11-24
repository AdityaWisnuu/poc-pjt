import { Injectable } from '@nestjs/common';
import type { PayAsset } from '@prisma/client';
import Decimal from 'decimal.js';
import { AppConfig } from '../config';
import { MarketService } from '../market/market.service';
import { PrismaService } from '../prisma.service';
import { BUY_FEE, SELL_FEE } from '../quote/quote-math';
import {
  Balances,
  BuyResult,
  ConvertibleAsset,
  SellResult,
  SettlementGateway,
  TransferResult,
} from './gateway';

const pause = (ms: number) => new Promise((done) => setTimeout(done, ms));
const simReference = (id: string) => `SIM-${id.slice(-8).toUpperCase()}`;

/** Uses live public prices but never sends an authenticated request. */
@Injectable()
export class SimGateway implements SettlementGateway {
  constructor(
    private readonly config: AppConfig,
    private readonly market: MarketService,
    private readonly prisma: PrismaService,
  ) {}

  async balances(): Promise<Balances> {
    const spent = await this.prisma.transaction.groupBy({
      by: ['asset'],
      where: { mode: 'SIMULATE', status: { not: 'FAILED' } },
      _sum: { assetSold: true },
    });
    const used = (asset: string) =>
      spent.find((row) => row.asset === asset)?._sum.assetSold?.toString() ?? 0;
    return {
      USDC: new Decimal(this.config.simUsdcBalance).minus(used('USDC')),
      USDT: new Decimal(this.config.simUsdtBalance).minus(used('USDT')),
      IDRX: new Decimal(this.config.simIdrxBalance).minus(used('IDRX')),
    };
  }

  async sellAsset(
    asset: ConvertibleAsset,
    quantity: Decimal,
    clientOrderId: string,
  ): Promise<SellResult> {
    await pause(1100);
    const pair = asset === 'USDC' ? 'usdcidr' : 'usdtidr';
    const { bids } = await this.market.depth(pair);
    const avgPrice = new Decimal(bids[0][0]);
    const gross = quantity.times(avgPrice);
    const feeIdr = gross.times(SELL_FEE).ceil().toNumber();
    const grossIdr = gross.floor().toNumber();
    return {
      reference: simReference(clientOrderId),
      assetSold: quantity,
      avgPrice,
      grossIdr,
      idrNet: grossIdr - feeIdr,
      feeIdr,
    };
  }

  async buyIdrx(idr: number, clientOrderId: string): Promise<BuyResult> {
    await pause(1000);
    const { asks } = await this.market.depth('idxidr');
    const avgPrice = new Decimal(asks[0][0]);
    const feeIdr = new Decimal(idr).times(BUY_FEE).ceil().toNumber();
    return {
      reference: simReference(clientOrderId),
      idrxBought: new Decimal(idr - feeIdr)
        .div(avgPrice)
        .toDecimalPlaces(0, Decimal.ROUND_DOWN),
      avgPrice,
      feeIdr,
    };
  }

  async sendAsset(
    asset: PayAsset,
    _amount: Decimal,
    requestId: string,
  ): Promise<TransferResult> {
    const appliedAt = new Date().toISOString();
    await pause(1200);
    return {
      withdrawId: simReference(requestId),
      txId: `SIM-${asset}-${requestId.slice(-8).toUpperCase()}`,
      fee: '0',
      appliedAt,
      completedAt: new Date().toISOString(),
    };
  }
}
