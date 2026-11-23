import {
  BadRequestException,
  ConflictException,
  GoneException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  OnApplicationBootstrap,
} from '@nestjs/common';
import { Transaction, TransactionStatus as Status } from '@prisma/client';
import Decimal from 'decimal.js';
import { v7 as uuidv7 } from 'uuid';
import { AppConfig } from '../config';
import { MarketService } from '../market/market.service';
import { PrismaService } from '../prisma.service';
import { parseQris, QrisError } from '../qris/qris';
import {
  idrToBuyIdrx,
  InsufficientLiquidityError,
  MIN_ORDER_IDR,
  MIN_PAYMENT_IDR,
  usdcToSellForIdr,
} from '../quote/quote-math';
import { SETTLEMENT_GATEWAY, UnknownOutcomeError } from '../settlement/gateway';
import type { SettlementGateway } from '../settlement/gateway';

const QUOTE_TTL_MS = 30_000;
const ACTIVE: Status[] = [
  'CREATED',
  'SELLING_USDC',
  'BUYING_IDRX',
  'SENDING_IDRX',
  'AWAITING_RECEIPT',
  'PAYING_MERCHANT',
];
const pause = (ms: number) => new Promise((done) => setTimeout(done, ms));

@Injectable()
export class OrdersService implements OnApplicationBootstrap {
  private readonly logger = new Logger(OrdersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly market: MarketService,
    private readonly config: AppConfig,
    @Inject(SETTLEMENT_GATEWAY) private readonly gateway: SettlementGateway,
  ) {}

  /** A restart interrupts in-flight work. Live orders are never assumed failed. */
  async onApplicationBootstrap() {
    const interrupted = await this.prisma.transaction.findMany({
      where: {
        status: {
          in: ['CREATED', 'SELLING_USDC', 'BUYING_IDRX', 'SENDING_IDRX'],
        },
      },
    });
    for (const order of interrupted) {
      const next: Status = order.mode === 'LIVE' ? 'NEEDS_REVIEW' : 'FAILED';
      await this.transition(order.id, order.status, next, 'system', {
        failureReason: 'Proses terhenti karena server restart',
      });
    }
    const staleSimulated = await this.prisma.transaction.findMany({
      where: {
        mode: 'SIMULATE',
        status: { in: ['AWAITING_RECEIPT', 'PAYING_MERCHANT'] },
      },
    });
    for (const order of staleSimulated) {
      await this.transition(order.id, order.status, 'FAILED', 'system', {
        failureReason: 'Proses terhenti karena server restart',
      });
    }
  }

  async wallet() {
    const [balances, usdcDepth, idrxDepth] = await Promise.all([
      this.gateway.balances(),
      this.market.depth('usdcidr'),
      this.market.depth('idxidr'),
    ]);
    const usdcBid = new Decimal(usdcDepth.bids[0][0]);
    const idrxBid = new Decimal(idrxDepth.bids[0][0]);
    const usdcIdr = balances.usdc.times(usdcBid).floor();
    const idrxIdr = balances.idrx.times(idrxBid).floor();
    return {
      mode: this.config.isLive ? 'live' : 'simulate',
      totalIdr: usdcIdr.plus(idrxIdr).toNumber(),
      assets: [
        {
          symbol: 'USDC',
          name: 'USD Coin',
          amount: balances.usdc.toFixed(4),
          idrValue: usdcIdr.toNumber(),
          rate: usdcBid.toNumber(),
          payable: true,
        },
        {
          symbol: 'IDRX',
          name: 'Rupiah Stablecoin',
          amount: balances.idrx.toFixed(0),
          idrValue: idrxIdr.toNumber(),
          rate: idrxBid.toNumber(),
          payable: false,
        },
      ],
    };
  }

  async createQuote(qr: string, enteredAmount?: number) {
    let parsed;
    try {
      parsed = parseQris(qr);
    } catch (error) {
      if (error instanceof QrisError) {
        throw new BadRequestException(error.message);
      }
      throw error;
    }

    const amountIdr = parsed.amountIdr ?? enteredAmount;
    if (amountIdr === undefined) {
      return {
        needsAmount: true,
        merchantName: parsed.merchantName,
        merchantCity: parsed.merchantCity,
        minIdr: MIN_PAYMENT_IDR,
        maxIdr: this.config.maxIdrPerRun,
      };
    }
    if (amountIdr < MIN_PAYMENT_IDR) {
      throw new BadRequestException(
        `Minimal pembayaran Rp${MIN_PAYMENT_IDR.toLocaleString('id-ID')}`,
      );
    }
    if (amountIdr > this.config.maxIdrPerRun) {
      throw new BadRequestException(
        `Maksimal pembayaran Rp${this.config.maxIdrPerRun.toLocaleString('id-ID')}`,
      );
    }

    const [usdcDepth, idrxDepth, balances] = await Promise.all([
      this.market.depth('usdcidr'),
      this.market.depth('idxidr'),
      this.gateway.balances(),
    ]);

    let buyIdr: number;
    let usdcAmount: Decimal;
    try {
      buyIdr = Math.max(idrToBuyIdrx(idrxDepth.asks, amountIdr), MIN_ORDER_IDR);
      usdcAmount = usdcToSellForIdr(usdcDepth.bids, buyIdr);
    } catch (error) {
      if (error instanceof InsufficientLiquidityError) {
        throw new BadRequestException('Likuiditas sedang tidak cukup');
      }
      throw error;
    }
    if (usdcAmount.gt(balances.usdc)) {
      throw new BadRequestException('Saldo USDC tidak cukup');
    }

    const quote = await this.prisma.quote.create({
      data: {
        id: uuidv7(),
        qrPayload: parsed.raw,
        merchantName: parsed.merchantName,
        merchantCity: parsed.merchantCity,
        amountIdr,
        buyIdr,
        usdcAmount: usdcAmount.toFixed(8),
        usdcIdrBid: usdcDepth.bids[0][0],
        idrxIdrAsk: idrxDepth.asks[0][0],
        expiresAt: new Date(Date.now() + QUOTE_TTL_MS),
      },
    });
    return {
      needsAmount: false,
      quoteId: quote.id,
      merchantName: quote.merchantName,
      merchantCity: quote.merchantCity,
      amountIdr,
      usdcAmount: usdcAmount.toFixed(6),
      rate: new Decimal(amountIdr).div(usdcAmount).toDecimalPlaces(0).toNumber(),
      expiresAt: quote.expiresAt.toISOString(),
      ttlSeconds: QUOTE_TTL_MS / 1000,
    };
  }

  async createOrder(quoteId: string) {
    const active = await this.prisma.transaction.count({
      where: { status: { in: [...ACTIVE, 'NEEDS_REVIEW'] } },
    });
    if (active > 0) {
      throw new ConflictException('Masih ada pembayaran yang berjalan');
    }

    const quote = await this.prisma.quote.findUnique({ where: { id: quoteId } });
    if (!quote) throw new NotFoundException('Kurs tidak ditemukan');
    if (quote.expiresAt.getTime() < Date.now()) {
      throw new GoneException('Kurs sudah kedaluwarsa');
    }

    const order = await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.quote.updateMany({
        where: { id: quoteId, usedAt: null },
        data: { usedAt: new Date() },
      });
      if (claimed.count !== 1) {
        throw new ConflictException('Kurs ini sudah dipakai');
      }
      const id = uuidv7();
      return tx.transaction.create({
        data: {
          id,
          quoteId,
          mode: this.config.isLive ? 'LIVE' : 'SIMULATE',
          merchantName: quote.merchantName,
          merchantCity: quote.merchantCity,
          amountIdr: quote.amountIdr,
          usdcPlanned: quote.usdcAmount,
          sellClientOrderId: uuidv7(),
          buyClientOrderId: uuidv7(),
          withdrawRequestId: uuidv7().replaceAll('-', ''),
          histories: {
            create: { id: uuidv7(), toStatus: 'CREATED', actor: 'app' },
          },
        },
      });
    });

    void this.run(order.id, quote.buyIdr);
    return this.present(order.id);
  }

  async list() {
    const rows = await this.prisma.transaction.findMany({
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    return rows.map((row) => this.summary(row));
  }

  present(id: string) {
    return this.prisma.transaction
      .findUnique({
        where: { id },
        include: { histories: { orderBy: { createdAt: 'asc' } } },
      })
      .then((order) => {
        if (!order) throw new NotFoundException('Pembayaran tidak ditemukan');
        return {
          ...this.summary(order),
          timeline: order.histories.map((h) => ({
            status: h.toStatus,
            at: h.createdAt.toISOString(),
          })),
        };
      });
  }

  async operatorReceived(id: string) {
    await this.requireLive(id);
    const moved = await this.transition(
      id,
      'AWAITING_RECEIPT',
      'PAYING_MERCHANT',
      'operator',
    );
    if (!moved) throw new ConflictException('Status pembayaran tidak sesuai');
    return this.present(id);
  }

  async operatorPaid(id: string) {
    await this.requireLive(id);
    const moved = await this.transition(id, 'PAYING_MERCHANT', 'SUCCESS', 'operator', {
      completedAt: new Date(),
    });
    if (!moved) throw new ConflictException('Status pembayaran tidak sesuai');
    return this.present(id);
  }

  private async requireLive(id: string) {
    const order = await this.prisma.transaction.findUnique({ where: { id } });
    if (!order) throw new NotFoundException('Pembayaran tidak ditemukan');
    if (order.mode !== 'LIVE') {
      throw new ConflictException('Bukan pembayaran live');
    }
  }

  private async run(id: string, buyIdr: number) {
    let current: Status = 'CREATED';
    const step = async (
      next: Status,
      data: Parameters<OrdersService['transition']>[4] = {},
    ) => {
      const moved = await this.transition(id, current, next, 'settlement', data);
      if (!moved) throw new Error(`Transisi ${current} -> ${next} gagal`);
      current = next;
    };

    try {
      const order = await this.prisma.transaction.findUniqueOrThrow({
        where: { id },
      });

      await step('SELLING_USDC');
      const sold = await this.gateway.sellUsdc(
        new Decimal(order.usdcPlanned.toString()),
        order.sellClientOrderId,
      );
      await step('BUYING_IDRX', {
        usdcSold: sold.usdcSold.toFixed(8),
        idrProceeds: sold.idrNet,
        feeIdr: sold.feeIdr,
      });

      if (sold.idrNet < buyIdr) {
        throw new Error('Hasil jual USDC kurang, dana tersimpan sebagai IDR');
      }
      const bought = await this.gateway.buyIdrx(buyIdr, order.buyClientOrderId);
      if (bought.idrxBought.lt(order.amountIdr)) {
        throw new Error('IDRX yang didapat kurang, dana tersimpan sebagai IDRX');
      }
      const sendAmount = new Decimal(order.amountIdr);
      await step('SENDING_IDRX', {
        idrxBought: bought.idrxBought.toFixed(2),
        feeIdr: sold.feeIdr + bought.feeIdr,
      });

      await this.gateway.sendIdrx(sendAmount, order.withdrawRequestId);
      await step('AWAITING_RECEIPT', { idrxSent: sendAmount.toFixed(2) });

      // Live orders wait here for the operator to confirm receipt and payment.
      if (order.mode === 'SIMULATE') {
        await pause(1100);
        await step('PAYING_MERCHANT');
        await pause(1300);
        await step('SUCCESS', { completedAt: new Date() });
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Kesalahan';
      const next: Status =
        error instanceof UnknownOutcomeError ? 'NEEDS_REVIEW' : 'FAILED';
      this.logger.error(`Order ${id} ${next}: ${message}`);
      await this.transition(id, current, next, 'settlement', {
        failureReason: message,
      });
    }
  }

  private async transition(
    id: string,
    from: Status,
    to: Status,
    actor: string,
    data: {
      usdcSold?: string;
      idrProceeds?: number;
      idrxBought?: string;
      idrxSent?: string;
      feeIdr?: number;
      failureReason?: string;
      completedAt?: Date;
    } = {},
  ): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.transaction.updateMany({
        where: { id, status: from },
        data: { ...data, status: to },
      });
      if (updated.count !== 1) return false;
      await tx.transactionHistory.create({
        data: {
          id: uuidv7(),
          transactionId: id,
          fromStatus: from,
          toStatus: to,
          actor,
          note: data.failureReason,
        },
      });
      return true;
    });
  }

  private summary(order: Transaction) {
    return {
      id: order.id,
      mode: order.mode,
      status: order.status,
      merchantName: order.merchantName,
      merchantCity: order.merchantCity,
      amountIdr: order.amountIdr,
      usdcAmount: new Decimal(
        (order.usdcSold ?? order.usdcPlanned).toString(),
      ).toFixed(6),
      feeIdr: order.feeIdr,
      failureReason: order.failureReason,
      createdAt: order.createdAt.toISOString(),
      completedAt: order.completedAt?.toISOString() ?? null,
    };
  }
}
