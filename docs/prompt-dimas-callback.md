Kerjakan sampai selesai dalam satu kali jalan di VPS ini. Jangan berhenti untuk
bertanya kecuali sebuah langkah bisa merusak service yang sudah ada. Pilih default
yang aman, lalu laporkan di akhir.

## Tujuan
Buat service callback withdraw Indodax untuk PoC, dengan notifikasi Telegram.

Wisnu mengirim USDC dari akun Indodax-nya ke username `dimasriat` lewat Trade API V2.
Sebelum WD diproses, Indodax mengirim POST ke Callback URL. WD hanya lanjut kalau
response body persis `ok`. Timeout koneksi 5 detik.

Parameter callback:
request_id, withdraw_currency, withdraw_address, withdraw_amount,
withdraw_memo, withdraw_username, requester_ip, request_date

PENTING: callback adalah persetujuan SEBELUM WD, bukan bukti USDC sudah masuk.
Docs tidak menyebut signature, jadi semua request dianggap tidak tepercaya.

## Batasan
- Jangan membuat transfer bank atau memanggil API Indodax.
- Jangan menyimpan API key/secret Indodax atau private key apa pun.
- Jangan mengganggu service yang sudah ada. Cek OS, port 80/443, reverse proxy,
  dan firewall dulu. Perubahan config harus additive dan divalidasi sebelum reload.

## Stack
- TypeScript + Fastify + SQLite di `/opt/indodax-callback`
- systemd, user non-root, bind ke 127.0.0.1
- HTTPS lewat reverse proxy yang sudah ada. Kalau belum ada, pasang Caddy.
- Pakai domain yang sudah mengarah ke VPS. Kalau tidak ada, pakai
  `<ip-dengan-strip>.sslip.io`.

## Env
Buat `/opt/indodax-callback/.env`, chmod 600, jangan di-log:
CALLBACK_PATH_TOKEN=<generate 32 byte hex>
ADMIN_TOKEN=<generate 32 byte hex>
EXPECTED_REQUESTER_IPS=<deteksi IPv4 publik VPS, tambah IPv6 kalau ada>
ALLOWED_USERNAMES=dimasriat
ALLOWED_CURRENCIES=usdc
MAX_AMOUNT_PER_WITHDRAW=5
MAX_AMOUNT_PER_DAY_WIB=20
INTENT_TTL_SECONDS=600
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=

Kalau variabel Telegram kosong, service tetap jalan dan mencatat warning.

## Endpoint
### POST /indodax/callback/:CALLBACK_PATH_TOKEN
Terima form-urlencoded, JSON, dan multipart.

Balas `ok` persis, status 200, text/plain, tanpa newline, HANYA jika:
1. request_id ada dan statusnya PENDING
2. belum kedaluwarsa
3. currency cocok (case-insensitive) dan ada di allowlist
4. username sama persis dengan intent dan ada di allowlist
5. amount sama persis secara desimal (`2` = `2.00000000`), tanpa float,
   simpan sebagai integer berskala 8 desimal
6. requester_ip ada di EXPECTED_REQUESTER_IPS
7. amount tidak melewati batas per WD dan batas harian WIB

Ubah PENDING -> APPROVED secara atomik. request_id yang sudah dipakai ditolak.
Selain itu, atau kalau ada error apa pun, balas `rejected` status 403.
Target response di bawah 1 detik. Simpan audit: waktu, payload, keputusan, alasan.
Jangan log CALLBACK_PATH_TOKEN, termasuk di access log reverse proxy.

### POST /internal/withdrawals
Auth `Authorization: Bearer ADMIN_TOKEN`, bandingkan timing-safe.
Body: { "request_id", "currency", "amount", "username" }
request_id alfanumerik 32-64 karakter. Tolak kalau melewati allowlist atau batas.
Duplikat dibalas 409.

### GET /internal/withdrawals/:request_id
Auth sama. Balas status, data intent, waktu, dan alasan penolakan terakhir.

### GET /health
Balas `{ "status": "ok" }`.

Tambahkan rate limit dan batas body 16 KB.

## Telegram
Kirim setelah keputusan callback dibuat, secara asynchronous, retry maksimal 3 kali.
Kegagalan Telegram tidak boleh menunda atau mengubah response ke Indodax.

Kalau disetujui:
🟡 WD DISETUJUI CALLBACK
Belum tentu masuk. Cek saldo USDC di Indodax sebelum transfer rekening.
Request: <request_id>
Jumlah: <amount> <currency>
Ke: <username>
Waktu: <waktu WIB sampai detik>

Kalau ditolak:
🔴 WD DITOLAK
Request: <request_id>
Jumlah: <amount> <currency>
Alasan: <alasan>
Waktu: <waktu WIB sampai detik>

Sediakan `npm run test:telegram` untuk mengirim pesan uji.

## User SSH khusus tunnel
Buat user `wisnu-tunnel` tanpa sudo. Pasang public key ini:
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/im/gRxdpSyxuYYXmg1ciN3s9NdlVhaIa45GyZAEg7

Tambahkan config ini lewat `/etc/ssh/sshd_config.d/` kalau di-include, atau di akhir
`sshd_config`. Kalau ada `AllowUsers`, tambahkan user ini:

Match User wisnu-tunnel
    PasswordAuthentication no
    AllowTcpForwarding local
    PermitOpen api.indodax.com:443
    X11Forwarding no
    AllowAgentForwarding no
    PermitTTY no
    ForceCommand /usr/sbin/nologin

Jalankan `sshd -t` sebelum reload. Jangan memutus sesi SSH yang sedang aktif.

## Test wajib lewat URL HTTPS
1. Intent valid + callback cocok -> `ok`
2. Callback dikirim ulang -> ditolak
3. request_id tidak dikenal -> ditolak
4. amount, username, currency, atau IP berbeda -> ditolak
5. Intent kedaluwarsa -> ditolak
6. Melewati batas per WD dan harian -> ditolak
7. `/internal/*` tanpa token -> 401
8. Token path salah -> 404
9. Restart service -> data tetap ada
10. Telegram gagal -> callback tetap menjawab benar

Hapus semua data test setelah selesai, lalu pastikan service aktif setelah restart.

## Laporan akhir
Tampilkan:
- Callback URL lengkap
- ADMIN_TOKEN
- IPv4 dan IPv6 publik VPS
- Port SSH
- Hasil 10 test
- Cara mengisi TELEGRAM_BOT_TOKEN dan TELEGRAM_CHAT_ID, lalu restart service

Jangan menulis Callback URL atau ADMIN_TOKEN ke repo maupun log.
