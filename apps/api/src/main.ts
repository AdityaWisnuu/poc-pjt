import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { AppConfig } from './config';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }),
  );
  // Only for previewing the app in a browser; unset in normal runs.
  if (process.env.DEV_CORS_ORIGIN) {
    app.enableCors({ origin: process.env.DEV_CORS_ORIGIN });
  }
  const config = app.get(AppConfig);
  await app.listen(config.port, '0.0.0.0');
  new Logger('Bootstrap').log(
    `API :${config.port} mode=${config.isLive ? 'LIVE' : 'simulate'}`,
  );
}
void bootstrap();
