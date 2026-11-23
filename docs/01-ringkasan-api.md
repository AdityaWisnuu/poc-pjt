# Langkah 1: Ringkasan API dan Hal yang Belum Jelas

Data diambil 22 November 2026, sekitar 23.15 WIB.
Sumber: repo `btcid/indodax-official-api-docs` (commit `8d1b409`, 10 Nov 2026), `docs.idrx.co`, API publik Indodax, dan RPC Base.
Tidak ada API key yang dipakai. Tidak ada order, withdraw, burn, atau redeem yang dijalankan.

## 1. Status verifikasi

| Yang dicek | Hasil | Status |
|---|---|---|
| Withdraw IDRX di Indodax dibuka? | Belum bisa dipastikan, butuh API key | **Belum terverifikasi** |
| Withdraw IDRX lewat jaringan apa? | Belum bisa dipastikan, butuh API key | **Belum terverifikasi** |
| Status pair IDRX | `idx_idr` dan `idx_usdt` berstatus `is_maintenance: 1` | Terverifikasi, arti flag tidak didokumentasikan |
| Order book `idx_idr` | Masih aktif: bid 0,998, ask 1 | Terverifikasi |
| Rekening redeem IDRX wajib senama? | Tidak mutlak, tapi beda nama butuh `notes` dan bisa direview | Terverifikasi dari docs |
| Rekening tarik IDR Indodax wajib senama? | **Wajib** senama dengan KYC | Terverifikasi dari docs |
| Kontrak IDRX di Base | `0x18Bc5bcC660cf2B9cE3cd51a404aFe1a0cBD3C22`, proxy, decimals 2, implementasi memuat `burnWithAccountNumber` | Terverifikasi on-chain |
| `demo-indodax.com` | HTTP 403 (Cloudflare Access), tidak disebut di docs resmi | **Tidak bisa diakses** |

`getInfo` tidak cukup untuk menjawab status withdraw. Field `withdraw_status` berlaku per akun, dan `network` hanya daftar jaringan. Yang tepat adalah `GET /api/v2/capital/config/getall`, field `withdrawAllEnable` dan `networkList[].withdrawEnable`, `withdrawFee`, `withdrawMin`, `contractAddress`.

## 2. Pemblokir

1. **Demo Indodax tertutup.** Aturan "mulai dari demo" belum bisa dijalankan tanpa akses.
2. **API IDRX bukan untuk akun biasa.** Docs menyebut API hanya untuk business account atau lewat kontak `support@idrx.co`. Business account butuh dokumen perusahaan dan rekening perusahaan.
3. **Alur C tidak bisa jalan dengan batas default.** Tarik IDR harus lebih dari Rp100.000, sedangkan `MAX_IDR_PER_RUN` default Rp100.000.
4. **Alur B bergantung pada status IDRX.** Pair dalam maintenance dan status withdraw belum diketahui.
5. **Callback dan whitelist alamat tidak bisa aktif bersamaan.** Satu API key hanya boleh memilih satu metode whitelist.

## 3. Endpoint Indodax

Base URL: `https://api.indodax.com`. Auth: header `X-APIKEY` dan `Sign` (**HMAC-SHA256** dari query string atau body), plus `timestamp` dan `recvWindow` (default 5000 ms).

TAPI lama (`/tapi`, HMAC-SHA512) sedang masa transisi dan akan dimatikan, tanggalnya belum diumumkan. Key TAPI lama tidak bisa dipakai di V2.

| Kebutuhan | Endpoint V2 | Limit | Catatan |
|---|---|---|---|
| Info akun | `GET /api/v2/account` | 300/menit | Menunjukkan izin key |
| Status coin dan jaringan | `GET /api/v2/capital/config/getall` | 50/menit | Sumber status withdraw |
| Buat order | `POST /api/v2/order` | 300/menit, 20/detik per pair | `newClientOrderId` maks. 36 karakter |
| Cek order | `GET /api/v2/order` | 300/menit | Order baru mungkin belum langsung muncul |
| Riwayat fill dan biaya | `GET /api/v2/myTrades` | 300/menit | `commission` sudah termasuk fee dan pajak |
| Riwayat deposit coin | `GET /api/v2/capital/deposit/hisrec` | 50/menit | Wajib per coin, rentang 90 hari |
| Riwayat withdraw coin | `GET /api/v2/capital/withdraw/history` | 50/menit | Wajib per coin, rentang 90 hari |
| Withdraw coin | `POST /api/v2/capital/withdraw/apply` | 50/menit | `withdrawOrderId` wajib, alfanumerik |
| Tarik IDR | `POST /api/v2/fiat/withdraw` | 50/menit | Di atas Rp100.000, `clientRequestId` maks. 36 karakter |
| Riwayat IDR | `GET /api/v2/fiat/orders` | 50/menit | Rentang 30 hari |

Pemetaan permintaan awal ke V2:

| Permintaan | Pengganti V2 |
|---|---|
| `getInfo` | `account` + `capital/config/getall` |
| `trade` | `POST /api/v2/order` |
| `getOrder` | `GET /api/v2/order` |
| `withdrawCoin` | `capital/withdraw/apply` |
| `transHistory` | `deposit/hisrec`, `withdraw/history`, `fiat/orders` |

Keamanan API key:

- Izin tersedia: Reading, Spot Trading, IDR & Crypto Withdrawal.
- Izin withdrawal wajib IP whitelist, dan IP itu berlaku untuk seluruh key.
- Key withdrawal baru atau yang diregenerasi baru bisa withdraw coin setelah **24 jam**.
- Metode whitelist: URL Callback, Address Management, atau Manual Whitelist. Pilih satu per key.
- Callback dikirim POST, timeout koneksi 5 detik, dan harus membalas persis `ok`.
- Withdraw ke alamat deposit Indodax milik sendiri ditolak.

Data pair saat dicek:

| Pair | Taker | Maker | Min. order | Maintenance |
|---|---|---|---|---|
| `usdt_idr` | 0,2% | 0,1% | Rp10.000 | 0 |
| `usdc_idr` | 0,2% | 0,1% | Rp10.000 | 0 |
| `idx_idr` | 0,2% | 0,1% | Rp10.000 | **1** |

Kode IDRX di Indodax adalah `idx`, simbol pair `IDXIDR` atau `idxidr` perlu dikonfirmasi saat uji order di demo.

## 4. Endpoint IDRX

Base URL: `https://api.idrx.co`. Header: `idrx-api-key`, `idrx-api-sig`, `idrx-api-ts`. Signature: HMAC-SHA256, secret di-decode base64, hasil base64url.

| Kebutuhan | Endpoint | Catatan |
|---|---|---|
| Daftar bank | `GET /transaction/method` | Sumber `bankCode` dan `bankName` |
| Tambah rekening | `POST /auth/add-bank-account` | Akun wajib terverifikasi |
| Lihat rekening | `GET /auth/get-bank-accounts` | Cek sebelum burn |
| Cek fee | `GET /transaction/get-additional-fees` | Kirim `feeType=REDEEM`, `payment`, `bankCode` |
| Redeem | `POST /transaction/redeem-request` | Idempoten per `txHash` |
| Status | `GET /transaction/user-transaction-history` | `transactionType=BURN`, filter `txHash` |
| Callback | URL diatur di dashboard | Tanpa signature dan tanpa retry |

Aturan redeem:

- Minimum Rp20.000. Fee Rp5.000 lewat BI-FAST di bawah Rp250 juta.
- Burn memakai `burnWithAccountNumber(amount, sha256("{bankName}_{bankAccountNumber}"))`, hash tanpa `0x`.
- **Burn tidak bisa dibatalkan.** Burn di luar alur resmi bisa menghilangkan dana.
- Rekening harus terdaftar sebelum burn. Kalau tidak, redeem ditolak `400 bank account is not registered`.
- Burn yang tidak terkonfirmasi dalam 2 jam menjadi `FAILED`.
- Pencairan direview IDRX, target maksimal 24 jam setelah burn terkonfirmasi.
- Kirim ulang `txHash` yang sama aman: balasan `200` dengan `alreadyExists: true`.

Status `burnStatus`:

- Masih berjalan: `PENDING`, `REQUESTED`, `IN_PROCESS`, `ACTION_REQUIRED`.
- Final: `SUCCESS`, `FAILED`, `INVALID`, `REJECTED`, `REFUNDED`.
- `ACTION_REQUIRED` bukan kegagalan dan tidak boleh di-retry.
- `REFUNDED` berarti IDRX dikembalikan ke wallet. Satu refund bisa mencakup beberapa burn.

Callback hanya dipakai sebagai pemicu. Kebenaran status diambil dari Transaction History. Callback redeem tidak punya `merchantOrderId`, jadi pencocokan memakai `txHash`.

## 5. Hal yang belum jelas

### Perlu keputusan Wisnu

1. Apakah ada akses ke `demo-indodax.com`? Kalau tidak, usulan: mock lokal dari contoh respons docs, ditambah data publik asli untuk quote.
2. Apakah sudah punya API key IDRX di akun pribadi? Kalau belum, perlu email ke `support@idrx.co`.
3. Pakai TAPI V2 untuk semua endpoint privat? Usulan: **ya**, karena TAPI lama akan dimatikan.
4. Metode whitelist withdraw? Usulan: **Address Management**. Endpoint callback tetap dibuat dan dites, tapi tidak aktif di key ini.
5. Batas nominal alur C? Usulan: default tetap Rp100.000 untuk alur A, alur C memakai `MAX_IDR_PER_RUN=150000`.

### Perlu dicek dengan key Reading

6. `withdrawEnable` IDRX per jaringan, apakah Base tersedia, serta `withdrawFee` dan `withdrawMin`.
7. Kode coin dan jaringan yang diterima V2 (`IDX` atau `IDRX`, `base` atau bentuk lain).
8. Kecocokan `contractAddress` IDRX di Indodax dengan kontrak Base di atas.

### Perlu ditanyakan ke support

9. Arti `is_maintenance: 1` pada pair IDRX (Indodax). Order book masih aktif, jadi tidak bisa diasumsikan trading mati.
10. Satuan `amountTransfer` di chain dengan 2 desimal (IDRX). Contoh docs memakai Polygon yang 0 desimal. Rp100.000 di Base sama dengan `10000000` unit on-chain.
11. Format signature POST (IDRX). Teks docs menyebut urutan method, URL, timestamp, body. Contoh kode memakai timestamp, method, URL, body, dan menandatangani body hasil transformasi base64 yang berbeda dari body yang dikirim.
12. Apakah akun individu bisa mendapat API key tanpa berubah menjadi business account (IDRX).

### Perlu dibuktikan dari transaksi kecil

13. Apakah PPh dikenakan saat membeli IDRX. Contoh docs menunjukkan `taxRate` 0,12% dan 0,21% tanpa penjelasan aturan. Laporan biaya memakai `commission` aktual dari `myTrades`.
14. Fee tarik IDR Indodax. Docs tidak mencantumkan angkanya.

## 6. Dampak ke desain

- `withdrawOrderId` memakai UUIDv7 tanpa tanda hubung, karena docs mensyaratkan alfanumerik.
- Key Indodax dipisah: Reading + Trading tanpa IP whitelist, dan Withdrawal dengan IP whitelist.
- Sebelum burn wajib ada pemeriksaan: rekening terdaftar, nominal sesuai desimal Base, saldo cukup, dan gas cukup.
- Alur A pada Rp100.000 menerima Rp95.000, jadi biaya tetap 500 bps. Pada Rp1.000.000 biayanya 50 bps. Laporan perlu menampilkan biaya pada beberapa nominal.
