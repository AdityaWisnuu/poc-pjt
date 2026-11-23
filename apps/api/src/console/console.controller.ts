import {
  Controller,
  Get,
  MessageEvent,
  NotFoundException,
  Param,
  Res,
  Sse,
} from '@nestjs/common';
import type { Response } from 'express';
import { join } from 'node:path';
import { interval, map, merge, Observable } from 'rxjs';
import { OrdersService } from '../orders/orders.service';

const ROOT = process.cwd();
const FILES: Record<string, string> = {
  'font.ttf': join(ROOT, '../mobile/assets/fonts/PlusJakartaSans.ttf'),
  'usdc.svg': join(ROOT, '../mobile/assets/tokens/usdc.svg'),
  'usdt.svg': join(ROOT, '../mobile/assets/tokens/usdt.svg'),
  'idrx.svg': join(ROOT, '../mobile/assets/tokens/idrx.svg'),
};

@Controller('console')
export class ConsoleController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  page(@Res() res: Response) {
    res.setHeader('Cache-Control', 'no-store');
    res.sendFile(join(ROOT, 'console/index.html'));
  }

  @Get('state')
  state() {
    return this.orders.consoleState();
  }

  @Sse('events')
  events(): Observable<MessageEvent> {
    return merge(
      this.orders.changes.pipe(map((id) => ({ type: 'change', data: { id } }))),
      interval(15000).pipe(map(() => ({ type: 'ping', data: {} }))),
    );
  }

  @Get('assets/:name')
  asset(@Param('name') name: string, @Res() res: Response) {
    const file = FILES[name];
    if (!file) throw new NotFoundException();
    res.sendFile(file);
  }
}

@Controller('merchant')
export class MerchantController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  page(@Res() res: Response) {
    res.setHeader('Cache-Control', 'no-store');
    res.sendFile(join(ROOT, 'console/merchant.html'));
  }

  @Get('state')
  state() {
    return this.orders.merchantState();
  }

  @Sse('events')
  events(): Observable<MessageEvent> {
    return merge(
      this.orders.changes.pipe(map(() => ({ type: 'change', data: {} }))),
      interval(15000).pipe(map(() => ({ type: 'ping', data: {} }))),
    );
  }
}
