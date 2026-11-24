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
import {
  PayAsset,
  Prisma,
  Transaction,
  TransactionStatus as Status,
} from '@prisma/client';
import Decimal from 'decimal.js';
import { Subject } from 'rxjs';
import { v7 as uuidv7 } from 'uuid';
import { AppConfig } from '../config';
import { MarketService } from '../market/market.service';
import { PrismaService } from '../prisma.service';
import { parseQris, QrisError } from '../qris/qris';
import {
  assetToSellForIdr,
  InsufficientLiquidityError,
  MIN_PAYMENT_IDR,
} from '../quote/quote-math';
import { SETTLEMENT_GATEWAY, UnknownOutcomeError } from '../settlement/gateway';
import type { Balances, SettlementGateway } from '../settlement/gateway';

const QUOTE_TTL_MS = 30_000;
const ASSETS: PayAsset[] = ['USDC', 'USDT', 'IDRX'];
const ASSET_NAMES: Record<PayAsset, string> = {
  USDC: 'USD Coin',
  USDT: 'Tether USD',
  IDRX: 'Rupiah Stablecoin',
};
const ACTIVE: Status[] = [
  'CREATED',
  'SENDING_ASSET',
  'SELLING_ASSET',
  'BUYING_IDRX',
  'SENDING_IDRX',
  'AWAITING_RECEIPT',
  'PAYING_MERCHANT',
];
const pause = (ms: number) => new Promise((done) => setTimeout(done, ms));
const displayAmount = (asset: PayAsset, amount: Decimal) =>
  amount.toFixed(asset === 'IDRX' ? 0 : 6);

interface PaymentOption {
  asset: PayAsset;
  amount: Decimal;
  bid: Decimal;
  rate: number;
  sufficient: boolean;
  /** Null when the asset can be sent now; otherwise why it cannot. */
  blocked: string | null;
}

@Injectable()
export class OrdersService implements OnApplicationBootstrap {
  private readonly logger = new Logger(OrdersService.name);
  /** Pushes a signal to the console and merchant screens on every state change. */
  readonly changes = new Subject<string>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly market: MarketService,
    private readonly config: AppConfig,
    @Inject(SETTLEMENT_GATEWAY) private readonly gateway: SettlementGateway,
  ) {}

  /** A restart interrupts in-flight work. Live orders are never assumed failed. */
  async onApplicationBootstrap() {
    const interrupted = await this.prisma.transaction.findMany({
      where: { status: { in: ACTIVE } },
    });
    for (const order of interrupted) {
      const next: Status = order.mode === 'LIVE' ? 'NEEDS_REVIEW' : 'FAILED';
      await this.transition(order.id, order.status, next, 'system', {
        failureReason: 'Proses terhenti karena server restart',
      });
    }
  }

  /** Why `asset` cannot be sent right now, or null when it can. */
  private blockedReason(asset: PayAsset, amount: Decimal): string | null {
    if (!this.config.isLive) return null;
    if (!this.config.liveAssets.includes(asset)) return 'Belum tersedia';
    const cap = this.config.maxUsdcPerTransfer;
    if (asset === 'USDC' && amount.gt(cap)) return `Maks. ${cap} USDC`;
    return null;
  }

  async wallet() {
    const [balances, usdc, usdt, idrx] = await Promise.all([
      this.gateway.balances(),
      this.market.depth('usdcidr'),
      this.market.depth('usdtidr'),
      this.market.depth('idxidr'),
    ]);
    const bids: Record<PayAsset, Decimal> = {
      USDC: new Decimal(usdc.bids[0][0]),
      USDT: new Decimal(usdt.bids[0][0]),
      IDRX: new Decimal(idrx.bids[0][0]),
    };
    const assets = ASSETS.map((asset) => {
      const idrValue = balances[asset].times(bids[asset]).floor().toNumber();
      return {
        symbol: asset,
        name: ASSET_NAMES[asset],
        amount: balances[asset].toFixed(asset === 'IDRX' ? 0 : 4),
        idrValue,
        rate: bids[asset].toNumber(),
        payable: !this.config.isLive || this.config.liveAssets.includes(asset),
      };
    });
    return {
      mode: this.config.isLive ? 'live' : 'simulate',
      totalIdr: assets.reduce((total, asset) => total + asset.idrValue, 0),
      assets,
    };
  }

  private async paymentOptions(
    amountIdr: number,
    balances: Balances,
  ): Promise<PaymentOption[]> {
    const [usdc, usdt] = await Promise.all([
      this.market.depth('usdcidr'),
      this.market.depth('usdtidr'),
    ]);
    const options: PaymentOption[] = [];

    // The Settlement Account sells what it receives, so the payer covers that
    // sale's fee and a price buffer. USDC and USDT carry 6 decimals.
    for (const [asset, depth] of [
      ['USDC', usdc],
      ['USDT', usdt],
    ] as const) {
      try {
        const amount = assetToSellForIdr(depth.bids, amountIdr).toDecimalPlaces(
          6,
          Decimal.ROUND_UP,
        );
        options.push({
          asset,
          amount,
          bid: new Decimal(depth.bids[0][0]),
          rate: new Decimal(amountIdr)
            .div(amount)
            .toDecimalPlaces(0)
            .toNumber(),
          sufficient: amount.lte(balances[asset]),
          blocked: this.blockedReason(asset, amount),
        });
      } catch (error) {
        if (!(error instanceof InsufficientLiquidityError)) throw error;
      }
    }

    const amount = new Decimal(amountIdr);
    options.push({
      asset: 'IDRX',
      amount,
      bid: new Decimal(1),
      rate: 1,
      sufficient: amount.lte(balances.IDRX),
      blocked: this.blockedReason('IDRX', amount),
    });
    return options;
  }

  async createQuote(qr: string, enteredAmount?: number, requested?: PayAsset) {
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

    const balances = await this.gateway.balances();
    const options = await this.paymentOptions(amountIdr, balances);
    const selected = requested
      ? options.find((option) => option.asset === requested)
      : (options.find((option) => !option.blocked && option.sufficient) ??
        options.find((option) => !option.blocked) ??
        options[0]);
    if (!selected) {
      throw new BadRequestException('Likuiditas sedang tidak cukup');
    }

    const quote = await this.prisma.quote.create({
      data: {
        id: uuidv7(),
        qrPayload: parsed.raw,
        merchantName: parsed.merchantName,
        merchantCity: parsed.merchantCity,
        amountIdr,
        buyIdr: 0,
        asset: selected.asset,
        assetAmount: selected.amount.toFixed(8),
        assetIdrBid: selected.bid.toFixed(4),
        idrxIdrAsk: 0,
        expiresAt: new Date(Date.now() + QUOTE_TTL_MS),
      },
    });
    return {
      needsAmount: false,
      quoteId: quote.id,
      merchantName: quote.merchantName,
      merchantCity: quote.merchantCity,
      amountIdr,
      asset: selected.asset,
      assetAmount: displayAmount(selected.asset, selected.amount),
      rate: selected.rate,
      sufficient: selected.sufficient,
      blocked: selected.blocked,
      options: options.map((option) => ({
        asset: option.asset,
        name: ASSET_NAMES[option.asset],
        amount: displayAmount(option.asset, option.amount),
        rate: option.rate,
        sufficient: option.sufficient,
        blocked: option.blocked,
      })),
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

    const quote = await this.prisma.quote.findUnique({
      where: { id: quoteId },
    });
    if (!quote) throw new NotFoundException('Kurs tidak ditemukan');
    if (quote.expiresAt.getTime() < Date.now()) {
      throw new GoneException('Kurs sudah kedaluwarsa');
    }
    const planned = new Decimal(quote.assetAmount.toString());
    const blocked = this.blockedReason(quote.asset, planned);
    if (blocked) {
      throw new BadRequestException(
        `${quote.asset} tidak bisa dipakai: ${blocked}`,
      );
    }
    const balances = await this.gateway.balances();
    if (planned.gt(balances[quote.asset])) {
      throw new BadRequestException(`Saldo ${quote.asset} tidak cukup`);
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
          asset: quote.asset,
          assetPlanned: quote.assetAmount,
          sellClientOrderId: uuidv7(),
          buyClientOrderId: uuidv7(),
          withdrawRequestId: uuidv7().replaceAll('-', ''),
          histories: {
            create: { id: uuidv7(), toStatus: 'CREATED', actor: 'app' },
          },
        },
      });
    });
    this.changes.next(order.id);

    void this.run(order.id);
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

  async consoleState() {
    const rows = await this.prisma.transaction.findMany({
      orderBy: { createdAt: 'desc' },
      take: 12,
      include: {
        quote: true,
        histories: { orderBy: { createdAt: 'asc' } },
      },
    });
    return {
      mode: this.config.isLive ? 'live' : 'simulate',
      serverTime: new Date().toISOString(),
      orders: rows.map((row) => {
        const evidence = row.evidence as Record<string, any>;
        return {
          ...this.summary(row),
          quote: {
            assetIdrBid: row.quote.assetIdrBid.toString(),
            assetPlanned: row.quote.assetAmount.toString(),
          },
          evidence,
          totalMs: row.completedAt
            ? row.completedAt.getTime() - row.createdAt.getTime()
            : null,
          timeline: row.histories.map((h) => ({
            status: h.toStatus,
            at: h.createdAt.toISOString(),
          })),
        };
      }),
    };
  }

  /** The merchant sees rupiah only, and only after payment is confirmed. */
  async merchantState() {
    const rows = await this.prisma.transaction.findMany({
      where: { status: 'SUCCESS' },
      orderBy: { completedAt: 'desc' },
      take: 8,
      select: {
        id: true,
        merchantName: true,
        merchantCity: true,
        amountIdr: true,
        completedAt: true,
      },
    });
    return {
      mode: this.config.isLive ? 'live' : 'simulate',
      payments: rows.map((row) => ({
        id: row.id,
        merchantName: row.merchantName,
        merchantCity: row.merchantCity,
        amountIdr: row.amountIdr,
        completedAt: row.completedAt?.toISOString() ?? null,
      })),
    };
  }

  async operatorReceived(id: string) {
    const order = await this.requireLive(id);
    const moved = await this.transition(
      id,
      'AWAITING_RECEIPT',
      'PAYING_MERCHANT',
      'operator',
      {
        evidence: {
          ...(order.evidence as Prisma.JsonObject),
          funding: { confirmedBy: 'Settlement Operator' },
        },
      },
    );
    if (!moved) throw new ConflictException('Status pembayaran tidak sesuai');
    return this.present(id);
  }

  async operatorPaid(id: string) {
    const order = await this.requireLive(id);
    const moved = await this.transition(
      id,
      'PAYING_MERCHANT',
      'SUCCESS',
      'operator',
      {
        completedAt: new Date(),
        evidence: {
          ...(order.evidence as Prisma.JsonObject),
          payment: {
            executedBy: 'Settlement Operator',
            channel: 'QRIS',
            amountIdr: order.amountIdr,
          },
        },
      },
    );
    if (!moved) throw new ConflictException('Status pembayaran tidak sesuai');
    return this.present(id);
  }

  private async requireLive(id: string) {
    const order = await this.prisma.transaction.findUnique({ where: { id } });
    if (!order) throw new NotFoundException('Pembayaran tidak ditemukan');
    if (order.mode !== 'LIVE') {
      throw new ConflictException('Bukan pembayaran live');
    }
    return order;
  }

  /**
   * Funding Leg is real in live mode: the payer's asset goes to the Settlement
   * Account and Indodax's history proves it. The Payment Leg (conversion at
   * the Settlement Operator and QRIS payout) is simulated for this PoC.
   */
  private async run(id: string) {
    let current: Status = 'CREATED';
    const evidence: Record<string, Prisma.InputJsonValue> = {};
    const step = async (
      next: Status,
      data: Parameters<OrdersService['transition']>[4] = {},
    ) => {
      const moved = await this.transition(
        id,
        current,
        next,
        'settlement',
        data,
      );
      if (!moved) throw new Error(`Transisi ${current} -> ${next} gagal`);
      current = next;
    };

    try {
      const order = await this.prisma.transaction.findUniqueOrThrow({
        where: { id },
      });
      const amount = new Decimal(order.assetPlanned.toString());
      const before = await this.readBalance(order.asset);

      await step('SENDING_ASSET');
      const transfer = await this.gateway.sendAsset(
        order.asset,
        amount,
        order.withdrawRequestId,
      );
      evidence.transfer = {
        asset: order.asset,
        amount: displayAmount(order.asset, amount),
        withdrawId: transfer.withdrawId,
        txId: transfer.txId,
        fee: transfer.fee,
        appliedAt: transfer.appliedAt,
        completedAt: transfer.completedAt,
        destination: 'Settlement Account',
        authorization: 'approved',
      };
      const after = await this.readBalance(order.asset);
      if (before && after) evidence.balances = { before, after };
      evidence.funding = {
        confirmedBy: order.mode === 'LIVE' ? 'Riwayat WD Indodax' : 'Simulasi',
        status: 'success',
      };
      await step('AWAITING_RECEIPT', {
        assetSold: amount.toFixed(8),
        evidence: { ...evidence },
      });

      await pause(900);
      await step('PAYING_MERCHANT', { evidence: { ...evidence } });
      await pause(1300);
      evidence.payment = {
        executedBy: 'Simulasi',
        channel: 'QRIS',
        amountIdr: order.amountIdr,
      };
      await step('SUCCESS', {
        completedAt: new Date(),
        evidence: { ...evidence },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Kesalahan';
      const next: Status =
        error instanceof UnknownOutcomeError ? 'NEEDS_REVIEW' : 'FAILED';
      this.logger.error(`Order ${id} ${next}: ${message}`);
      await this.transition(id, current, next, 'settlement', {
        failureReason: message,
        evidence: { ...evidence },
      });
    }
  }

  /** Evidence only: a failed balance read must never stop a settlement. */
  private async readBalance(asset: PayAsset): Promise<string | null> {
    try {
      const balances = await this.gateway.balances();
      return balances[asset].toFixed(asset === 'IDRX' ? 0 : 4);
    } catch {
      return null;
    }
  }

  private async transition(
    id: string,
    from: Status,
    to: Status,
    actor: string,
    data: {
      assetSold?: string;
      idrProceeds?: number;
      idrxBought?: string;
      idrxSent?: string;
      feeIdr?: number;
      failureReason?: string;
      completedAt?: Date;
      evidence?: Prisma.InputJsonValue;
    } = {},
  ): Promise<boolean> {
    const moved = await this.prisma.$transaction(async (tx) => {
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
    if (moved) this.changes.next(id);
    return moved;
  }

  private summary(order: Transaction) {
    const transfer = (order.evidence as Record<string, any> | null)?.transfer;
    return {
      transfer: transfer
        ? {
            withdrawId: transfer.withdrawId ?? null,
            txId: transfer.txId ?? null,
            completedAt: transfer.completedAt ?? null,
          }
        : null,
      id: order.id,
      mode: order.mode,
      status: order.status,
      merchantName: order.merchantName,
      merchantCity: order.merchantCity,
      amountIdr: order.amountIdr,
      asset: order.asset,
      assetAmount: displayAmount(
        order.asset,
        new Decimal((order.assetSold ?? order.assetPlanned).toString()),
      ),
      feeIdr: order.feeIdr,
      failureReason: order.failureReason,
      createdAt: order.createdAt.toISOString(),
      completedAt: order.completedAt?.toISOString() ?? null,
    };
  }
}
