# poc-pjt

PoC bayar QRIS dengan stablecoin. User scan QRIS, aset kripto berkurang, merchant tetap menerima rupiah.

- `apps/mobile`: Flutter (iOS dan Android)
- `apps/api`: NestJS, Prisma, PostgreSQL

## Menjalankan

```bash
pnpm install
cp .env.example .env
pnpm db:up
pnpm db:migrate
pnpm --filter api build && pnpm --filter api start:prod
```

Build ke iPhone, dengan IP laptop di jaringan yang sama:

```bash
cd apps/mobile
flutter build ios --release --dart-define=API_BASE=http://<IP-LAPTOP>:3000
xcrun devicectl device install app --device <DEVICE-ID> build/ios/iphoneos/Runner.app
```

## Mode

Default `simulate`: harga dari order book publik Indodax, tanpa order atau WD sungguhan.

Mode `live` butuh `SETTLEMENT_MODE=live` di `apps/api/.env`, `DRY_RUN=false`, dan tunnel aktif (`pnpm tunnel`).
