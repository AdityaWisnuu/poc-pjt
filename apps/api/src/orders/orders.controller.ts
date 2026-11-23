import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
} from 'class-validator';
import { AppConfig } from '../config';
import { crc16Ccitt } from '../qris/qris';
import { OrdersService } from './orders.service';

class CreateQuoteDto {
  @IsString()
  @Length(40, 1024)
  qr!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1_000_000_000)
  amountIdr?: number;
}

class CreateOrderDto {
  @IsUUID()
  quoteId!: string;
}

const tlv = (tag: string, value: string) =>
  `${tag}${String(value.length).padStart(2, '0')}${value}`;

@Controller()
export class OrdersController {
  constructor(
    private readonly orders: OrdersService,
    private readonly config: AppConfig,
  ) {}

  @Get('health')
  health() {
    return { status: 'ok', mode: this.config.isLive ? 'live' : 'simulate' };
  }

  @Get('wallet')
  wallet() {
    return this.orders.wallet();
  }

  @Post('quotes')
  quote(@Body() body: CreateQuoteDto) {
    return this.orders.createQuote(body.qr, body.amountIdr);
  }

  @Post('orders')
  create(@Body() body: CreateOrderDto) {
    return this.orders.createOrder(body.quoteId);
  }

  @Get('orders')
  list() {
    return this.orders.list();
  }

  @Get('orders/:id')
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.orders.present(id);
  }

  @Post('orders/:id/operator/received')
  received(@Param('id', ParseUUIDPipe) id: string) {
    return this.orders.operatorReceived(id);
  }

  @Post('orders/:id/operator/paid')
  paid(@Param('id', ParseUUIDPipe) id: string) {
    return this.orders.operatorPaid(id);
  }

  /** Demo QR for rehearsing without a merchant. Disabled in live mode. */
  @Get('dev/sample-qr')
  sampleQr() {
    if (this.config.isLive) throw new NotFoundException();
    const body = [
      tlv('00', '01'),
      tlv('01', '12'),
      tlv('26', tlv('00', 'ID.CO.QRIS.WWW') + tlv('01', '936000000000000001')),
      tlv('52', '5812'),
      tlv('53', '360'),
      tlv('54', '25000'),
      tlv('58', 'ID'),
      tlv('59', 'Kopi Klaten'),
      tlv('60', 'KLATEN'),
    ].join('');
    const unsigned = `${body}6304`;
    return { qr: unsigned + crc16Ccitt(unsigned) };
  }
}
