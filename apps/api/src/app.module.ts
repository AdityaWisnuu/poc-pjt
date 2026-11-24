import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppConfig } from './config';
import {
  ConsoleController,
  MerchantController,
} from './console/console.controller';
import { MarketService } from './market/market.service';
import { OrdersController } from './orders/orders.controller';
import { OrdersService } from './orders/orders.service';
import { PrismaService } from './prisma.service';
import { FxService } from './remit/fx.service';
import { BankInaSim, PartnerSim } from './remit/partners.sim';
import {
  RecipientController,
  RemitConsoleController,
  RemitController,
} from './remit/remit.controller';
import { RemitService } from './remit/remit.service';
import { SETTLEMENT_GATEWAY } from './settlement/gateway';
import { IndodaxClient } from './settlement/indodax.client';
import { LiveGateway } from './settlement/live.gateway';
import { SimGateway } from './settlement/sim.gateway';

@Module({
  imports: [
    // apps/api/.env wins, so SETTLEMENT_MODE stays explicit for this service.
    ConfigModule.forRoot({ envFilePath: ['.env', '../../.env'] }),
  ],
  controllers: [
    OrdersController,
    ConsoleController,
    MerchantController,
    RemitController,
    RemitConsoleController,
    RecipientController,
  ],
  providers: [
    AppConfig,
    PrismaService,
    MarketService,
    IndodaxClient,
    SimGateway,
    LiveGateway,
    OrdersService,
    FxService,
    BankInaSim,
    PartnerSim,
    RemitService,
    {
      provide: SETTLEMENT_GATEWAY,
      inject: [AppConfig, SimGateway, LiveGateway],
      useFactory: (config: AppConfig, sim: SimGateway, live: LiveGateway) =>
        config.isLive ? live : sim,
    },
  ],
})
export class AppModule {}
