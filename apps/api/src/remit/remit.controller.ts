import {
  Body,
  Controller,
  Get,
  MessageEvent,
  Param,
  ParseUUIDPipe,
  Post,
  Res,
  Sse,
} from '@nestjs/common';
import type { RemitDirection } from '@prisma/client';
import {
  IsIn,
  IsNumber,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
} from 'class-validator';
import type { Response } from 'express';
import { join } from 'node:path';
import { interval, map, merge, Observable } from 'rxjs';
import { RemitService } from './remit.service';

class RemitQuoteDto {
  @IsIn(['INBOUND', 'OUTBOUND'])
  direction!: RemitDirection;

  @IsString()
  @Length(2, 2)
  corridor!: string;

  @IsString()
  @Length(3, 4)
  fundingCurrency!: string;

  @IsNumber({ maxDecimalPlaces: 6 })
  @Min(0.000001)
  @Max(1_000_000_000)
  amount!: number;

  @IsString()
  @Length(2, 60)
  senderName!: string;

  @IsString()
  @Length(2, 10)
  bank!: string;

  @IsString()
  @Length(6, 34)
  account!: string;
}

class RemitCreateDto {
  @IsUUID()
  quoteId!: string;
}

const ROOT = process.cwd();
const stream = (service: RemitService): Observable<MessageEvent> =>
  merge(
    service.changes.pipe(map((id) => ({ type: 'change', data: { id } }))),
    interval(15000).pipe(map(() => ({ type: 'ping', data: {} }))),
  );

@Controller('remit')
export class RemitController {
  constructor(private readonly remit: RemitService) {}

  @Get('catalog')
  catalog() {
    return this.remit.catalog();
  }

  @Post('quotes')
  quote(@Body() body: RemitQuoteDto) {
    return this.remit.createQuote(body);
  }

  @Post('transfers')
  create(@Body() body: RemitCreateDto) {
    return this.remit.create(body.quoteId);
  }

  @Get('transfers')
  list() {
    return this.remit.list();
  }

  @Get('transfers/:id')
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.remit.present(id);
  }
}

@Controller('console/remit')
export class RemitConsoleController {
  constructor(private readonly remit: RemitService) {}

  @Get()
  page(@Res() res: Response) {
    res.setHeader('Cache-Control', 'no-store');
    res.sendFile(join(ROOT, 'console/remit.html'));
  }

  @Get('state')
  state() {
    return this.remit.consoleState();
  }

  @Sse('events')
  events() {
    return stream(this.remit);
  }
}

@Controller('penerima')
export class RecipientController {
  constructor(private readonly remit: RemitService) {}

  @Get()
  page(@Res() res: Response) {
    res.setHeader('Cache-Control', 'no-store');
    res.sendFile(join(ROOT, 'console/penerima.html'));
  }

  @Get('state')
  state() {
    return this.remit.recipientState();
  }

  @Sse('events')
  events() {
    return stream(this.remit);
  }
}
