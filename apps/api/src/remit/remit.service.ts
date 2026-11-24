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
  Prisma,
  RemitDirection,
  Remittance,
  RemitStatus as Status,
} from '@prisma/client';
import Decimal from 'decimal.js';
import { Subject } from 'rxjs';
import { v7 as uuidv7 } from 'uuid';
import { AppConfig } from '../config';
import { MarketService } from '../market/market.service';
import { PrismaService } from '../prisma.service';
import {
  assetFromBuying,
  idrFromSelling,
  InsufficientLiquidityError,
} from '../quote/quote-math';
import { SETTLEMENT_GATEWAY, UnknownOutcomeError } from '../settlement/gateway';
import type { SettlementGateway } from '../settlement/gateway';
import {
  Corridor,
  corridor as findCorridor,
  CORRIDORS,
  ID_BANKS,
  ID_SAMPLES,
  PARTNER_SPREAD,
  Rail,
  SANCTIONS_SAMPLE,
  TYPE_LABELS,
} from './corridors';
import { FX_SOURCE, FxService } from './fx.service';
import { AccountNotFoundError, BankInaSim, PartnerSim } from './partners.sim';

const QUOTE_TTL_MS = 60_000;
const MIN_USDC = new Decimal('0.5');
const MIN_IDR = 10_000;
const ACTIVE: Status[] = [
  'CREATED',
  'SCREENING',
  'COLLECTING',
  'SENDING_ASSET',
  'CONVERTING',
  'PAYING_OUT',
];
const QRIS_ACTIVE = [
  'CREATED',
  'SENDING_ASSET',
  'SELLING_ASSET',
  'BUYING_IDRX',
  'SENDING_IDRX',
  'AWAITING_RECEIPT',
  'PAYING_MERCHANT',
  'NEEDS_REVIEW',
] as const;
const pause = (ms: number) => new Promise((done) => setTimeout(done, ms));
const places = (currency: string) =>
  ['IDR', 'JPY', 'KRW'].includes(currency) ? 0 : currency === 'USDC' ? 6 : 2;
const round = (value: Decimal, currency: string) =>
  value.toDecimalPlaces(places(currency), Decimal.ROUND_DOWN);
const fmt = (value: Decimal, dp: number) =>
  Number(value.toFixed(dp)).toLocaleString('id-ID', {
    minimumFractionDigits: dp,
    maximumFractionDigits: dp,
  });
const mask = (account: string) => `•••• ${account.slice(-4)}`;

export interface Party {
  name: string;
  country: string;
}

export interface Recipient extends Party {
  bank: string;
  bankName: string;
  account: string;
}

export interface Step {
  status: Status;
  label: string;
  detail: string;
  /** True when this step moves real value in live mode. */
  real: boolean;
}

export interface QuoteInput {
  direction: RemitDirection;
  corridor: string;
  fundingCurrency: string;
  amount: number;
  senderName: string;
  bank: string;
  account: string;
}

@Injectable()
export class RemitService implements OnApplicationBootstrap {
  private readonly logger = new Logger(RemitService.name);
  readonly changes = new Subject<string>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly market: MarketService,
    private readonly fx: FxService,
    private readonly config: AppConfig,
    private readonly bankIna: BankInaSim,
    private readonly partner: PartnerSim,
    @Inject(SETTLEMENT_GATEWAY) private readonly gateway: SettlementGateway,
  ) {}

  /** Same rule as QRIS: an interrupted live transfer is checked by a human. */
  async onApplicationBootstrap() {
    const interrupted = await this.prisma.remittance.findMany({
      where: { status: { in: ACTIVE } },
    });
    for (const item of interrupted) {
      const next: Status = item.mode === 'LIVE' ? 'NEEDS_REVIEW' : 'FAILED';
      await this.transition(item.id, item.status, next, 'system', {
        failureReason: 'Proses terhenti karena server restart',
      });
    }
  }

  catalog() {
    return {
      mode: this.config.isLive ? 'live' : 'simulate',
      maxUsdc: this.capUsdc().toNumber(),
      maxIdr: this.config.maxIdrPerRun,
      minUsdc: MIN_USDC.toNumber(),
      minIdr: MIN_IDR,
      types: TYPE_LABELS,
      corridors: CORRIDORS.map((c) => ({
        code: c.code,
        country: c.country,
        currency: c.currency,
        type: c.type,
        typeLabel: c.typeLabel,
        rail: c.rail,
        reason: c.reason,
        partner: c.partner,
        volume2025: c.volume2025,
        banks: c.banks,
        samples: c.samples,
        funding: {
          INBOUND: this.fundingOptions('INBOUND', c),
          OUTBOUND: this.fundingOptions('OUTBOUND', c),
        },
      })),
      indonesia: { banks: ID_BANKS, samples: ID_SAMPLES },
    };
  }

  private capUsdc() {
    return this.config.isLive
      ? new Decimal(this.config.maxUsdcPerTransfer)
      : new Decimal(1000);
  }

  /** Inbound crypto senders hold USDC; everywhere else people pay local money. */
  private fundingOptions(direction: RemitDirection, c: Corridor): string[] {
    if (direction === 'INBOUND')
      return c.rail === 'crypto' ? ['USDC'] : [c.currency];
    return c.rail === 'fiat' ? ['IDR'] : ['IDR', 'USDC'];
  }

  private plan(
    direction: RemitDirection,
    c: Corridor,
    funding: string,
  ): Step[] {
    const usesUsdc = c.rail !== 'fiat';
    const steps: Step[] = [
      {
        status: 'SCREENING',
        label: 'Cek kepatuhan',
        detail: 'Nama pengirim & penerima vs daftar sanksi',
        real: false,
      },
    ];
    if (direction === 'INBOUND') {
      if (c.rail !== 'crypto') {
        steps.push({
          status: 'COLLECTING',
          label: `Dana ${c.currency} diterima`,
          detail: `${c.partner} · simulasi`,
          real: false,
        });
      }
      if (usesUsdc) {
        steps.push(
          {
            status: 'SENDING_ASSET',
            label: 'USDC masuk ke PJT',
            detail:
              c.rail === 'crypto'
                ? 'Dari akun exchange pengirim'
                : `Dari ${c.partner}`,
            real: true,
          },
          {
            status: 'CONVERTING',
            label: 'Konversi ke rupiah',
            detail: 'USDC/IDR di Indodax · simulasi',
            real: false,
          },
        );
      }
      steps.push({
        status: 'PAYING_OUT',
        label: 'Transfer ke rekening',
        detail:
          c.rail === 'fiat'
            ? 'Dari saldo IDR pre-funded · simulasi'
            : 'BI-FAST lewat Bank INA · simulasi',
        real: false,
      });
      return steps;
    }

    steps.push({
      status: 'COLLECTING',
      label: funding === 'USDC' ? 'USDC pengirim dikunci' : 'Rupiah diterima',
      detail:
        funding === 'USDC'
          ? 'Saldo USDC pengirim'
          : usesUsdc
            ? 'VA PJT, lalu beli USDC · simulasi'
            : 'VA PJT · simulasi',
      real: false,
    });
    if (usesUsdc) {
      steps.push(
        {
          status: 'SENDING_ASSET',
          label: `USDC ke mitra ${c.country}`,
          detail: c.partner,
          real: true,
        },
        {
          status: 'CONVERTING',
          label: `Konversi ke ${c.currency}`,
          detail: `Oleh mitra · simulasi`,
          real: false,
        },
      );
    }
    steps.push({
      status: 'PAYING_OUT',
      label: 'Transfer ke rekening',
      detail:
        c.rail === 'fiat'
          ? `${c.partner}, dana pre-funded · simulasi`
          : `${c.payoutChannel} oleh mitra · simulasi`,
      real: false,
    });
    return steps;
  }

  async createQuote(input: QuoteInput) {
    const c = findCorridor(input.corridor);
    if (!c) throw new BadRequestException('Koridor tidak tersedia');
    const funding = input.fundingCurrency.toUpperCase();
    if (!this.fundingOptions(input.direction, c).includes(funding)) {
      throw new BadRequestException(
        `${funding} tidak tersedia untuk koridor ini`,
      );
    }
    const amount = new Decimal(input.amount);
    if (amount.lte(0)) throw new BadRequestException('Nominal tidak valid');

    const senderName = input.senderName.trim().toUpperCase();
    let recipient: Recipient;
    try {
      if (input.direction === 'INBOUND') {
        const hit = this.bankIna.inquiry(input.bank, input.account);
        recipient = {
          name: hit.name,
          country: 'Indonesia',
          bank: input.bank,
          bankName: hit.bankName,
          account: input.account,
        };
      } else {
        const hit = this.partner.inquiry(c, input.bank, input.account);
        recipient = {
          name: hit.name,
          country: c.country,
          bank: input.bank,
          bankName: hit.bankName,
          account: input.account,
        };
      }
    } catch (error) {
      if (error instanceof AccountNotFoundError) {
        throw new BadRequestException(error.message);
      }
      throw error;
    }
    const sender: Party = {
      name: senderName,
      country: input.direction === 'INBOUND' ? c.country : 'Indonesia',
    };

    const priced = await this.price(input.direction, c, funding, amount);
    const steps = this.plan(input.direction, c, funding);
    const blocked = this.blockedReason(steps, priced.usdcAmount);

    const quote = await this.prisma.remitQuote.create({
      data: {
        id: uuidv7(),
        direction: input.direction,
        fundingCurrency: funding,
        sendAmount: amount.toFixed(8),
        usdcAmount: priced.usdcAmount.toFixed(8),
        receiveAmount: priced.receiveAmount.toFixed(2),
        receiveCurrency: priced.receiveCurrency,
        pricing: {
          ...priced.pricing,
          corridor: c.code,
        } as Prisma.InputJsonValue,
        sender: sender as unknown as Prisma.InputJsonValue,
        recipient: recipient as unknown as Prisma.InputJsonValue,
        expiresAt: new Date(Date.now() + QUOTE_TTL_MS),
      },
    });
    return {
      quoteId: quote.id,
      direction: input.direction,
      corridor: this.corridorView(c),
      fundingCurrency: funding,
      sendAmount: amount.toFixed(places(funding)),
      usdcAmount: priced.usdcAmount.toFixed(6),
      receiveAmount: priced.receiveAmount.toFixed(
        places(priced.receiveCurrency),
      ),
      receiveCurrency: priced.receiveCurrency,
      pricing: priced.pricing,
      sender,
      recipient: { ...recipient, account: mask(recipient.account) },
      steps,
      blocked,
      expiresAt: quote.expiresAt.toISOString(),
      ttlSeconds: QUOTE_TTL_MS / 1000,
    };
  }

  private corridorView(c: Corridor) {
    return {
      code: c.code,
      country: c.country,
      currency: c.currency,
      type: c.type,
      typeLabel: c.typeLabel,
      rail: c.rail,
      reason: c.reason,
      partner: c.partner,
      volume2025: c.volume2025,
    };
  }

  /** Why the real leg cannot run now, or null. */
  private blockedReason(steps: Step[], usdc: Decimal): string | null {
    const real = steps.some((s) => s.real);
    if (!real) return null;
    if (usdc.lt(MIN_USDC)) return `Minimal ${MIN_USDC} USDC`;
    if (usdc.gt(this.capUsdc()))
      return `Maks. ${this.capUsdc()} USDC per transfer`;
    return null;
  }

  private async price(
    direction: RemitDirection,
    c: Corridor,
    funding: string,
    amount: Decimal,
  ) {
    const spread = new Decimal(PARTNER_SPREAD[c.rail]);
    const spreadPct = spread.times(100).toFixed(1);
    const assumptions = [
      '1 USDC dihitung = 1 USD',
      `Margin mitra ${spreadPct.replace(".", ",")}% (asumsi simulasi)`,
    ];
    const lines: { label: string; value: string }[] = [];
    const local = await this.fx.perUsd(c.currency);
    const fxNote = { source: FX_SOURCE, updated: local.updated };

    if (funding === 'IDR' && amount.lt(MIN_IDR)) {
      throw new BadRequestException(
        `Minimal Rp${MIN_IDR.toLocaleString('id-ID')}`,
      );
    }
    if (funding === 'IDR' && amount.gt(this.config.maxIdrPerRun)) {
      throw new BadRequestException(
        `Maksimal Rp${this.config.maxIdrPerRun.toLocaleString('id-ID')}`,
      );
    }

    try {
      if (direction === 'INBOUND') {
        if (c.rail === 'fiat') {
          const idr = await this.fx.perUsd('IDR');
          const perUnit = idr.rate.div(local.rate);
          const receive = round(
            amount.times(perUnit).times(new Decimal(1).minus(spread)),
            'IDR',
          );
          lines.push(
            {
              label: `Kurs referensi 1 ${c.currency}`,
              value: `Rp${fmt(perUnit, 2)}`,
            },
            { label: 'Margin mitra', value: `${spreadPct.replace(".", ",")}%` },
          );
          return this.result(
            new Decimal(0),
            receive,
            'IDR',
            lines,
            assumptions,
            fxNote,
            `1 ${c.currency} = Rp${fmt(receive.div(amount), 2)}`,
          );
        }
        const usdc =
          c.rail === 'crypto'
            ? amount
            : amount
                .div(local.rate)
                .times(new Decimal(1).minus(spread))
                .toDecimalPlaces(6, Decimal.ROUND_DOWN);
        const { bids } = await this.market.depth('usdcidr');
        const sale = idrFromSelling(bids, usdc);
        if (c.rail !== 'crypto') {
          lines.push(
            {
              label: `Kurs referensi 1 USD`,
              value: `${fmt(local.rate, 2)} ${c.currency}`,
            },
            { label: 'Margin mitra', value: `${spreadPct.replace(".", ",")}%` },
            { label: 'USDC dikirim mitra', value: `${fmt(usdc, 6)} USDC` },
          );
        }
        lines.push(
          {
            label: 'Harga beli teratas USDC/IDR',
            value: `Rp${fmt(new Decimal(bids[0][0]), 0)}`,
          },
          { label: 'Biaya jual Indodax', value: `Rp${fmt(sale.fee, 0)}` },
        );
        const unit = c.rail === 'crypto' ? 'USDC' : c.currency;
        return this.result(
          usdc,
          sale.net,
          'IDR',
          lines,
          c.rail === 'crypto'
            ? ['Konversi di Indodax: simulasi, harga dikunci saat quote']
            : assumptions,
          fxNote,
          `1 ${unit} = Rp${fmt(sale.net.div(amount), unit === 'USDC' ? 0 : 2)}`,
        );
      }

      if (c.rail === 'fiat') {
        const idr = await this.fx.perUsd('IDR');
        const perIdr = local.rate.div(idr.rate);
        const receive = round(
          amount.times(perIdr).times(new Decimal(1).minus(spread)),
          c.currency,
        );
        lines.push(
          {
            label: `Kurs referensi Rp1.000`,
            value: `${fmt(perIdr.times(1000), 4)} ${c.currency}`,
          },
          { label: 'Margin mitra', value: `${spreadPct.replace(".", ",")}%` },
        );
        return this.result(
          new Decimal(0),
          receive,
          c.currency,
          lines,
          assumptions,
          fxNote,
          `Rp1.000 = ${fmt(receive.div(amount).times(1000), 4)} ${c.currency}`,
        );
      }

      let usdc = amount;
      if (funding === 'IDR') {
        const { asks } = await this.market.depth('usdcidr');
        const buy = assetFromBuying(asks, amount.toNumber());
        usdc = buy.quantity;
        lines.push(
          {
            label: 'Harga jual teratas USDC/IDR',
            value: `Rp${fmt(new Decimal(asks[0][0]), 0)}`,
          },
          { label: 'Biaya beli Indodax', value: `Rp${fmt(buy.fee, 0)}` },
          { label: 'USDC dibeli', value: `${fmt(usdc, 6)} USDC` },
        );
      }
      const receive = round(
        usdc.times(local.rate).times(new Decimal(1).minus(spread)),
        c.currency,
      );
      lines.push(
        {
          label: 'Kurs referensi 1 USD',
          value: `${fmt(local.rate, 2)} ${c.currency}`,
        },
        { label: 'Margin mitra', value: `${spreadPct.replace(".", ",")}%` },
      );
      const unit = funding === 'USDC' ? '1 USDC' : 'Rp1.000';
      const per =
        funding === 'USDC'
          ? receive.div(amount)
          : receive.div(amount).times(1000);
      return this.result(
        usdc,
        receive,
        c.currency,
        lines,
        [
          ...(funding === 'IDR' ? ['Pembelian USDC di Indodax: simulasi'] : []),
          ...assumptions,
        ],
        fxNote,
        `${unit} = ${fmt(per, 4)} ${c.currency}`,
      );
    } catch (error) {
      if (error instanceof InsufficientLiquidityError) {
        throw new BadRequestException('Likuiditas sedang tidak cukup');
      }
      throw error;
    }
  }

  private result(
    usdcAmount: Decimal,
    receiveAmount: Decimal,
    receiveCurrency: string,
    lines: { label: string; value: string }[],
    assumptions: string[],
    fx: { source: string; updated: string },
    rate: string,
  ) {
    return {
      usdcAmount,
      receiveAmount,
      receiveCurrency,
      pricing: { rate, lines, assumptions, fx },
    };
  }

  async create(quoteId: string) {
    const busy = await Promise.all([
      this.prisma.remittance.count({
        where: { status: { in: [...ACTIVE, 'NEEDS_REVIEW'] } },
      }),
      this.prisma.transaction.count({
        where: { status: { in: [...QRIS_ACTIVE] } },
      }),
    ]);
    if (busy[0] + busy[1] > 0) {
      throw new ConflictException(
        'Masih ada transfer yang berjalan atau perlu dicek',
      );
    }

    const quote = await this.prisma.remitQuote.findUnique({
      where: { id: quoteId },
    });
    if (!quote) throw new NotFoundException('Quote tidak ditemukan');
    if (quote.expiresAt.getTime() < Date.now()) {
      throw new GoneException('Kurs sudah kedaluwarsa');
    }
    const pricing = quote.pricing as Record<string, any>;
    const c = findCorridor(pricing.corridor as string);
    if (!c) throw new BadRequestException('Koridor tidak tersedia');
    const steps = this.plan(quote.direction, c, quote.fundingCurrency);
    const usdc = new Decimal(quote.usdcAmount.toString());
    const blocked = this.blockedReason(steps, usdc);
    if (blocked) throw new BadRequestException(blocked);
    if (steps.some((s) => s.real)) {
      const balances = await this.gateway.balances();
      if (usdc.gt(balances.USDC))
        throw new BadRequestException('Saldo USDC tidak cukup');
    }

    const created = await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.remitQuote.updateMany({
        where: { id: quoteId, usedAt: null },
        data: { usedAt: new Date() },
      });
      if (claimed.count !== 1)
        throw new ConflictException('Quote ini sudah dipakai');
      return tx.remittance.create({
        data: {
          id: uuidv7(),
          quoteId,
          direction: quote.direction,
          mode: this.config.isLive ? 'LIVE' : 'SIMULATE',
          fundingCurrency: quote.fundingCurrency,
          sendAmount: quote.sendAmount,
          usdcAmount: quote.usdcAmount,
          receiveAmount: quote.receiveAmount,
          receiveCurrency: quote.receiveCurrency,
          sender: quote.sender as Prisma.InputJsonValue,
          recipient: quote.recipient as Prisma.InputJsonValue,
          withdrawRequestId: uuidv7().replaceAll('-', ''),
          evidence: { corridor: c.code, pricing } as Prisma.InputJsonValue,
          histories: {
            create: { id: uuidv7(), toStatus: 'CREATED', actor: 'app' },
          },
        },
      });
    });
    this.changes.next(created.id);
    void this.run(created.id);
    return this.present(created.id);
  }

  private async run(id: string) {
    let current: Status = 'CREATED';
    const row = await this.prisma.remittance.findUniqueOrThrow({
      where: { id },
    });
    const base = row.evidence as Record<string, any>;
    const c = findCorridor(base.corridor as string)!;
    const evidence: Record<string, Prisma.InputJsonValue> = { ...base };
    const sender = row.sender as unknown as Party;
    const recipient = row.recipient as unknown as Recipient;
    const usdc = new Decimal(row.usdcAmount.toString());
    const receive = new Decimal(row.receiveAmount.toString());
    const steps = this.plan(row.direction, c, row.fundingCurrency).map(
      (s) => s.status,
    );

    const step = async (next: Status) => {
      const moved = await this.transition(id, current, next, 'remit', {
        evidence: { ...evidence },
      });
      if (!moved) throw new Error(`Transisi ${current} -> ${next} gagal`);
      current = next;
    };

    try {
      for (const status of steps) {
        await step(status);
        if (status === 'SCREENING') {
          await pause(700);
          const names = [sender.name, recipient.name];
          const hit = names.find((n) =>
            SANCTIONS_SAMPLE.includes(n.toUpperCase()),
          );
          evidence.screening = {
            list: 'Daftar sanksi contoh (simulasi DTTOT)',
            checked: names,
            result: hit ? 'cocok' : 'lolos',
          };
          if (hit)
            throw new Error(`${hit} cocok dengan daftar sanksi (contoh)`);
        }
        if (status === 'COLLECTING') {
          if (row.direction === 'INBOUND') {
            const done = await this.partner.collect(c, id);
            evidence.collection = {
              by: c.partner,
              amount: new Decimal(row.sendAmount.toString()).toFixed(
                places(row.fundingCurrency),
              ),
              currency: row.fundingCurrency,
              reference: done.reference,
              mode: 'Simulasi',
            };
          } else {
            await pause(900);
            evidence.collection = {
              by:
                row.fundingCurrency === 'USDC'
                  ? 'Saldo USDC pengirim'
                  : 'VA PJT',
              amount: new Decimal(row.sendAmount.toString()).toFixed(
                places(row.fundingCurrency),
              ),
              currency: row.fundingCurrency,
              ...(row.fundingCurrency === 'IDR' && c.rail !== 'fiat'
                ? { purchase: `${usdc.toFixed(6)} USDC di Indodax` }
                : {}),
              mode: row.fundingCurrency === 'USDC' ? 'Saldo' : 'Simulasi',
            };
          }
        }
        if (status === 'SENDING_ASSET') {
          const before = await this.readUsdc();
          const transfer = await this.gateway.sendAsset(
            'USDC',
            usdc,
            row.withdrawRequestId,
          );
          const after = await this.readUsdc();
          evidence.transfer = {
            from:
              row.direction === 'INBOUND'
                ? c.rail === 'crypto'
                  ? 'Pengirim'
                  : c.partner
                : 'PJT',
            to: row.direction === 'INBOUND' ? 'PJT' : c.partner,
            amount: usdc.toFixed(6),
            withdrawId: transfer.withdrawId,
            txId: transfer.txId,
            fee: transfer.fee,
            completedAt: transfer.completedAt,
            confirmedBy:
              row.mode === 'LIVE' ? 'Riwayat WD Indodax' : 'Simulasi',
            ...(before && after ? { balances: { before, after } } : {}),
          };
        }
        if (status === 'CONVERTING') {
          if (row.direction === 'INBOUND') {
            await pause(800);
            const { bids } = await this.market.depth('usdcidr');
            const sale = idrFromSelling(bids, usdc);
            evidence.conversion = {
              by: 'PJT di Indodax',
              pair: 'USDC/IDR',
              price: new Decimal(bids[0][0]).toFixed(0),
              net: sale.net.toFixed(0),
              locked: receive.toFixed(0),
              mode: 'Simulasi',
            };
          } else {
            const done = await this.partner.convert(id);
            const local = await this.fx.perUsd(c.currency);
            evidence.conversion = {
              by: c.partner,
              pair: `USDC/${c.currency}`,
              price: local.rate.toFixed(2),
              net: receive.toFixed(places(c.currency)),
              reference: done.reference,
              mode: 'Simulasi',
            };
          }
        }
        if (status === 'PAYING_OUT') {
          const payout =
            row.direction === 'INBOUND'
              ? await this.bankIna.transferInterbank(
                  row.withdrawRequestId.slice(0, 20),
                )
              : await this.partner.payout(c, id);
          const reference =
            'referenceNo' in payout ? payout.referenceNo : payout.reference;
          evidence.payout = {
            by:
              row.direction === 'INBOUND'
                ? c.rail === 'fiat'
                  ? 'Juara Remiten (dana pre-funded)'
                  : 'Juara Remiten · Bank INA'
                : c.partner,
            channel: payout.channel,
            reference,
            ...('responseCode' in payout
              ? { responseCode: payout.responseCode }
              : {}),
            amount: receive.toFixed(places(row.receiveCurrency)),
            currency: row.receiveCurrency,
            recipient: recipient.name,
            bank: recipient.bankName,
            account: mask(recipient.account),
            mode: 'Simulasi',
            ...(c.rail === 'fiat'
              ? {
                  settlement:
                    'Penyelesaian dengan mitra lewat transfer bank, terpisah',
                }
              : {}),
          };
        }
      }
      await this.transition(id, current, 'SUCCESS', 'remit', {
        completedAt: new Date(),
        evidence: { ...evidence },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Kesalahan';
      const next: Status =
        error instanceof UnknownOutcomeError ? 'NEEDS_REVIEW' : 'FAILED';
      this.logger.error(`Remitansi ${id} ${next}: ${message}`);
      await this.transition(id, current, next, 'remit', {
        failureReason: message,
        evidence: { ...evidence },
      });
    }
  }

  private async readUsdc(): Promise<string | null> {
    try {
      return (await this.gateway.balances()).USDC.toFixed(4);
    } catch {
      return null;
    }
  }

  async list() {
    const rows = await this.prisma.remittance.findMany({
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    return rows.map((row) => this.summary(row));
  }

  async present(id: string) {
    const row = await this.prisma.remittance.findUnique({
      where: { id },
      include: { histories: { orderBy: { createdAt: 'asc' } } },
    });
    if (!row) throw new NotFoundException('Transfer tidak ditemukan');
    return {
      ...this.summary(row),
      timeline: row.histories.map((h) => ({
        status: h.toStatus,
        at: h.createdAt.toISOString(),
      })),
    };
  }

  async consoleState() {
    const rows = await this.prisma.remittance.findMany({
      orderBy: { createdAt: 'desc' },
      take: 12,
      include: { histories: { orderBy: { createdAt: 'asc' } } },
    });
    return {
      mode: this.config.isLive ? 'live' : 'simulate',
      serverTime: new Date().toISOString(),
      items: rows.map((row) => ({
        ...this.summary(row),
        evidence: row.evidence,
        totalMs: row.completedAt
          ? row.completedAt.getTime() - row.createdAt.getTime()
          : null,
        timeline: row.histories.map((h) => ({
          status: h.toStatus,
          at: h.createdAt.toISOString(),
        })),
      })),
    };
  }

  /** What the beneficiary's banking app would show: money in, nothing about crypto. */
  async recipientState() {
    const rows = await this.prisma.remittance.findMany({
      where: { status: 'SUCCESS' },
      orderBy: { completedAt: 'desc' },
      take: 8,
    });
    return {
      mode: this.config.isLive ? 'live' : 'simulate',
      items: rows.map((row) => {
        const s = this.summary(row);
        return {
          id: s.id,
          direction: s.direction,
          amount: s.receiveAmount,
          currency: s.receiveCurrency,
          recipient: s.recipient,
          senderName: s.sender.name,
          senderCountry: s.sender.country,
          completedAt: s.completedAt,
        };
      }),
    };
  }

  private summary(row: Remittance) {
    const evidence = row.evidence as Record<string, any>;
    const c = findCorridor(evidence.corridor as string);
    const recipient = row.recipient as unknown as Recipient;
    return {
      id: row.id,
      mode: row.mode,
      direction: row.direction,
      status: row.status,
      corridor: c ? this.corridorView(c) : null,
      steps: c ? this.plan(row.direction, c, row.fundingCurrency) : [],
      fundingCurrency: row.fundingCurrency,
      sendAmount: new Decimal(row.sendAmount.toString()).toFixed(
        places(row.fundingCurrency),
      ),
      usdcAmount: new Decimal(row.usdcAmount.toString()).toFixed(6),
      receiveAmount: new Decimal(row.receiveAmount.toString()).toFixed(
        places(row.receiveCurrency),
      ),
      receiveCurrency: row.receiveCurrency,
      sender: row.sender as unknown as Party,
      recipient: { ...recipient, account: mask(recipient.account) },
      transfer: evidence.transfer
        ? {
            withdrawId: evidence.transfer.withdrawId,
            txId: evidence.transfer.txId,
          }
        : null,
      payoutReference: evidence.payout?.reference ?? null,
      failureReason: row.failureReason,
      createdAt: row.createdAt.toISOString(),
      completedAt: row.completedAt?.toISOString() ?? null,
    };
  }

  private async transition(
    id: string,
    from: Status,
    to: Status,
    actor: string,
    data: {
      failureReason?: string;
      completedAt?: Date;
      evidence?: Prisma.InputJsonValue;
    } = {},
  ): Promise<boolean> {
    const moved = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.remittance.updateMany({
        where: { id, status: from },
        data: { ...data, status: to },
      });
      if (updated.count !== 1) return false;
      await tx.remitHistory.create({
        data: {
          id: uuidv7(),
          remittanceId: id,
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
}
