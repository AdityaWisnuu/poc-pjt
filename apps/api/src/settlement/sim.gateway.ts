import { Injectable } from '@nestjs/common';
import Decimal from 'decimal.js';
import { AppConfig } from '../config';
import { MarketService } from '../market/market.service';
import { PrismaService } from '../prisma.service';
import { BUY_FEE, SELL_FEE } from '../quote/quote-math';
import { BuyResult, SellResult, SettlementGateway } from './gateway';

const pause = (ms: number) => new Promise((done) => setTimeout(done, ms));

/** Uses live public prices but never sends an authenticated request. */
@Injectable()
export class SimGateway implements SettlementGateway {
  constructor(
    private readonly config: AppConfig,
    private readonly market: MarketService,
    private readonly prisma: PrismaService,
  ) {}

  async balances() {
    const spent = await this.prisma.transaction.aggregate({
      where: { mode: 'SIMULATE', status: { not: 'FAILED' } },
      _sum: { usdcSold: true },
    });
    return {
      usdc: new Decimal(this.config.simUsdcBalance).minus(
        spent._sum.usdcSold?.toString() ?? 0,
      ),
      idrx: new Decimal(this.config.simIdrxBalance),
    };
  }

  async sellUsdc(quantity: Decimal): Promise<SellResult> {
    await pause(1100);
    const { bids } = await this.market.depth('usdcidr');
    const gross = quantity.times(bids[0][0]);
    const feeIdr = gross.times(SELL_FEE).ceil().toNumber();
    return {
      usdcSold: quantity,
      idrNet: gross.floor().toNumber() - feeIdr,
      feeIdr,
    };
  }

  async buyIdrx(idr: number): Promise<BuyResult> {
    await pause(1000);
    const { asks } = await this.market.depth('idxidr');
    const feeIdr = new Decimal(idr).times(BUY_FEE).ceil().toNumber();
    return {
      idrxBought: new Decimal(idr - feeIdr)
        .div(asks[0][0])
        .toDecimalPlaces(0, Decimal.ROUND_DOWN),
      feeIdr,
    };
  }

  async sendIdrx(): Promise<void> {
    await pause(1200);
  }
}
