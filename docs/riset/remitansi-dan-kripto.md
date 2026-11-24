# Riset: Remitansi dan Regulasi Aset Kripto

Tanggal: 24 November 2026. Bahan untuk memetakan PJT ke produk remitansi.

Semua klaim diberi sumber. Yang belum dicek ke sumber primer ditandai **(belum terverifikasi)**. Ini bukan opini hukum. Bagian yang berupa analisis atas teks aturan ditulis sebagai analisis.

---

## Ringkasan

1. **Remitansi itu izin BI.** Setelah PBI 10/2025 berlaku (31 Mar 2026), remitansi digital tanpa saldo pengguna masuk **paket 2** (modal Rp5 miliar). Kalau memegang saldo pengguna, masuk **paket 1** (modal Rp15 miliar).
2. **Kripto itu izin OJK.** Membeli kripto dari publik atau menjual ke publik sebagai usaha adalah kegiatan **PAKD** (modal Rp100 miliar). Sejak UU 4/2026, menjalankan usaha kripto tanpa izin OJK diancam pidana sampai 10 tahun.
3. **Penyelenggara pembayaran dilarang menyentuh kripto.** PBI 10/2025 Pasal 119 melarang PSP menerima virtual currency sebagai sumber dana, memprosesnya, dan **mengaitkannya** dengan transaksi pembayaran. Stablecoin rupiah seperti IDRT disebut eksplisit sebagai contoh.
4. **Stablecoin bukan alat pembayaran.** UU 4/2026 membolehkan stablecoin jadi "alat transaksi" dengan persetujuan OJK, tapi menegaskan stablecoin tidak bisa dipakai sebagai alat pembayaran langsung.
5. **Di dunia, remitansi stablecoin selalu memisahkan izin per langkah.** Exchange atau VASP berizin mengurus kripto. Lembaga transfer uang atau e-money berizin mengurus pembayaran ke penerima. Di Indonesia belum ditemukan satu pun layanan remitansi stablecoin masuk yang resmi berjalan.
6. **Akibatnya untuk model PJT sekarang:** PT yang menerima USDC dari banyak pembayar lalu menjualnya ke rupiah berisiko dianggap menjalankan kegiatan PAKD tanpa izin. PT itu juga tidak bisa sekaligus jadi penyelenggara pembayaran yang menyentuh USDC.

---

## 1. Cara kerja remitansi lintas negara

Bagian ini pengetahuan umum industri **(belum terverifikasi ke sumber primer)**.

**Alur dasar:** pengirim → penyedia remitansi di negara asal → dana pindah antar negara → mitra pencairan di negara tujuan → penerima.

| Model | Cara memindahkan dana | Kecepatan | Kelemahan |
|---|---|---|---|
| Bank (SWIFT) | Pesan SWIFT (MT103/pacs.008), dana lewat rekening nostro/vostro bank koresponden. Kadang ada bank perantara | 1–5 hari kerja | Mahal, fee perantara tidak jelas |
| MTO (Western Union) | **Pre-funding**: dana ditaruh dulu di mitra pencair negara tujuan, penyelesaian antar mitra berkala (net settlement) | Menit | Modal kerja tertahan di pre-funding |
| Fintech (Wise) | Saldo mata uang lokal di banyak negara. Arus masuk dan keluar **disalinghapuskan (netting)**, hanya selisihnya yang dipindah | Menit sampai 1 hari | Butuh volume dua arah |

**Pilihan pencairan di Indonesia:** transfer bank (BI-FAST/SKNBI), e-wallet, atau ambil tunai di agen/kantor pos.

**Dari mana biaya datang:** fee tetap, **selisih kurs terhadap kurs tengah** (sering yang terbesar), fee bank perantara, biaya modal pre-funding, biaya kepatuhan (KYC/AML), dan fee pencairan.

## 2. Pasar remitansi Indonesia

**Remitansi PMI (masuk ke Indonesia):**
- 2024: US$15,702 miliar. 2025: **US$17,255 miliar** (sementara). [BI SEKI V.31](https://www.bi.go.id/seki/tabel/TABEL5_31.pdf)
- 2026: Q1 US$4,539 miliar, Q2 US$4,627 miliar, Q3 US$4,719 miliar (Q3 perkiraan). Sumber sama.
- KP2MI menyebut Rp288 triliun untuk 2025. [Kompas](https://nasional.kompas.com/read/2026/02/24/16290761/remitansi-dari-tki-pada-2025-capai-rp-288-triliun-gerakkan-ekonomi)

**Koridor terbesar 2025 (juta USD):** [BI SEKI V.31](https://www.bi.go.id/seki/tabel/TABEL5_31.pdf)

| Negara asal | 2025 |
|---|---|
| Malaysia | 4.772 |
| Arab Saudi | 3.991 |
| Taiwan | 2.972 |
| Hong Kong | 2.634 |
| Korea Selatan | 716 |
| Jepang | 651 |
| Singapura | 479 |

Jepang dan Korea tumbuh paling cepat. Jepang naik dari 136 (Q1-2025) ke 253 (Q3-2026).

**Biaya kirim:**
- Rata-rata biaya kirim ke Indonesia 2,44% (2023), turun dari 7,30% (2016). [World Bank API](https://api.worldbank.org/v2/country/IDN/indicator/SI.RMT.COST.IB.ZS?format=json)
- Rata-rata global 6,49% (Q1-2025). [World Bank RPW](https://remittanceprices.worldbank.org/sites/default/files/rpw_main_report_and_annex_q125_1_0.pdf) **(belum terverifikasi, hanya dari cuplikan pencarian)**
- Malaysia→Indonesia sekitar 5,41% (Q4-2024) **(belum terverifikasi)**.
- Target SDG 10.c: biaya di bawah 3% pada 2030, tidak ada koridor di atas 5%, dihitung untuk kiriman US$200. [SDG metadata](https://worldbank.github.io/sdg-metadata/phase-2/metadata/en/10-c-1)

## 3. Regulasi remitansi (Bank Indonesia)

### Aturan yang berlaku

- **PBI 10/2025** tentang Pengaturan Industri Sistem Pembayaran. Ditetapkan 24 Des 2025, berlaku **31 Mar 2026**. [PDF](https://www.bi.go.id/id/publikasi/peraturan/Documents/PBI-102025.pdf)
- **PADG 32/2025** sebagai aturan pelaksana, berlaku 31 Mar 2026, mencabut PADG 24/7/PADG/2022. [Halaman BI](https://www.bi.go.id/id/publikasi/peraturan/Pages/PADG_322025.aspx)
- PBI 22/23/PBI/2020 **sudah dicabut** (PBI 10/2025 Pasal 185). PBI 23/6/PBI/2021 masih berlaku sepanjang tidak bertentangan (Pasal 184).
- Dasar undang-undang: UU 3/2011 tentang Transfer Dana. [BPK](https://peraturan.bpk.go.id/Details/39133)

### Paket aktivitas (PBI 10/2025 Pasal 34)

| Paket | Isi | Modal disetor minimum (PADG 32/2025 Pasal 102) |
|---|---|---|
| 1 (1A/1B) | Penatausahaan sumber dana (akun/saldo pengguna), penerusan data/perintah pembayaran, penerusan transfer dana digital dan nondigital | Rp15 miliar |
| 2 | Penerusan data/perintah pembayaran, penerusan transfer dana digital dan nondigital | Rp5 miliar |
| 3 | Hanya penerusan transfer dana nondigital | Rp1 miliar (kalau menyediakan sistem untuk PJP lain) atau Rp500 juta |

- Remitansi adalah contoh "penerusan perintah transfer dana" (Penjelasan Pasal 10 ayat 4 huruf b). Definisinya: transfer yang sumber dananya **bukan** dari akun yang ditatausahakan PSP itu sendiri.
- "Digital" artinya disediakan aplikasi mobile/web untuk pengguna (Penjelasan Pasal 34).
- **Remitansi digital tanpa saldo pengguna → paket 2.** Kalau memegang saldo atau akun pengguna, itu penatausahaan sumber dana dan hanya ada di **paket 1**.
- Paket bisa naik atau turun lewat persetujuan BI. [FAQ PADG 32/2025](https://www.bi.go.id/id/publikasi/peraturan/Documents/FAQ-PADG-322025.pdf) no. 13.

### Syarat lain

- Wajib izin BI (Pasal 37). Pemohon: Bank Umum atau badan hukum Indonesia selain bank (Pasal 38).
- Kepemilikan: minimal 15% saham WNI/badan hukum Indonesia, dan pengendalian (minimal 51%) di pihak Indonesia (Pasal 44).
- Bentuk badan: paket 1 wajib PT. Paket 2 yang hanya remitansi boleh PT atau badan hukum Indonesia lain (Pasal 38).
- Modal berjalan: beban transaksi 0,1% dari nominal transaksi masuk dan keluar, dalam dan luar negeri (PADG Pasal 166).
- Tidak ada izin terpisah untuk remitansi masuk dan keluar. Bedanya di aturan valas dan devisa.
- Batas nominal per transaksi remitansi tidak ditemukan di PBI 10/2025 maupun PADG 32/2025.

### AML, KYC, pelaporan

- **PBI 10/2024** dan **PADG 15/2025** (APU-PPT). Mencakup PJSP selain bank yang menjalankan remitansi. [PBI 10/2024](https://www.bi.go.id/id/publikasi/peraturan/Pages/PBI_102024.aspx), [PADG 15/2025](https://www.bi.go.id/id/publikasi/peraturan/Pages/PADG_152025.aspx)
- Pengirim asal wajib CDD (identifikasi dan verifikasi) **pengirim**. Penerima akhir wajib CDD **penerima**. Data transfer wajib diteruskan lengkap (setara travel rule).
- Laporan ke PPATK lewat goAML: transaksi mencurigakan (LTKM), transaksi tunai (LTKT), transfer dana dari/ke luar negeri (LTKL/IFTI).
- Valas: ambang dokumen underlying turun ke US$50rb per bulan mulai 1 Apr 2026 **(belum terverifikasi, nomor aturannya belum ketemu)**.
- Laporan lalu lintas devisa: PBI 9/2024 **(status aturan pelaksananya belum terverifikasi)**.

## 4. Regulasi aset kripto (OJK)

### Perpindahan pengawas

- UU 4/2023 (P2SK) memindahkan pengawasan kripto dari Bappebti ke OJK. Berlaku efektif **10 Jan 2025** lewat PP 49/2024.
- **POJK 27/2024** berlaku 10 Jan 2025. [OJK](https://ojk.go.id/id/regulasi/Pages/POJK-27-2024-AKD-AK.aspx)
- **POJK 23/2025** mengubahnya, berlaku 10 Nov 2025. Isinya antara lain: dana konsumen wajib di lembaga kliring, pedagang wajib memiliki dan mengendalikan sistemnya sendiri. [peraturan.go.id](https://www.peraturan.go.id/files/peraturan-ojk-no-23-tahun-2025.pdf)
- **UU 4/2026** (perubahan UU P2SK), diundangkan 17 Jun 2026. [BPK](https://peraturan.bpk.go.id/Details/350166/uu-no-4-tahun-2026)
  - Pasal 221A ayat (2): lembaga kripto wajib izin OJK.
  - Pasal 221A ayat (8): semua aktivitas kripto, termasuk lewat dompet digital, wajib lewat atau dilaporkan ke bursa.
  - **Pasal 304A: usaha kripto tanpa izin OJK diancam penjara paling lama 10 tahun.**
  - Penjelasan Pasal 213: stablecoin boleh jadi "alat transaksi" dengan rekomendasi bursa dan persetujuan OJK, tapi **tidak bisa dipakai sebagai alat pembayaran langsung**.
  - Aturan turunan OJK untuk UU ini belum terbit.

### Peran dan modal (POJK 23/2025)

| Peran | Modal disetor minimum | Yang sudah berizin (21 Apr 2026) |
|---|---|---|
| Bursa | Rp1 triliun | CFX, ICEx |
| Lembaga kliring | Rp500 miliar | KKI, PT Pranata Karya Solusi |
| Kustodian | Rp250 miliar | PT Kustodian Koin Indonesia, PT Arganis Konsultindo Utama |
| **Pedagang (PAKD)** | **Rp100 miliar** (ekuitas minimal Rp50 miliar) | 25 PAKD, termasuk **Indodax** (S-18/D.07/2025) |

[Daftar OJK per 21 Apr 2026](https://ojk.go.id/id/Fungsi-Utama/ITSK/Perizinan-ITSK-Aset-Keuangan-Digital-Aset-Kripto/Documents/Daftar%20Penyelenggara%20Perdagangan%20Aset%20Keuangan%20Digital%20Posisi%2021%20April%202026.pdf). OJK menyebut 28 PAKD per Sep 2026 [(Kontan, belum terverifikasi)](https://keuangan.kontan.co.id/news/ojk-catat-kini-ada-28-pedagang-aset-keuangan-digital).

### Kegiatan yang butuh izin PAKD (POJK 23/2025 Pasal 51)

1. Jual/beli aset digital dengan rupiah.
2. Tukar antar aset digital.
3. Menyimpan aset milik konsumen.
4. Transfer antar wallet.

- **Perusahaan boleh jadi konsumen biasa** di PAKD, termasuk menjual USDC miliknya sendiri (FAQ POJK 27 no. 5).
- **Perusahaan yang membeli kripto dari publik sebagai usaha** menjalankan kegiatan huruf 1, jadi butuh izin PAKD.
- **Mitra atau white-label:** PAKD dilarang memakai agen (Pasal 52). Kerja sama dengan pihak "aktivitas pendukung" wajib disetujui OJK. Salah satu yang diakui: layanan penghubung dengan penyedia jasa pembayaran (Pasal 102).

### Stablecoin

- USDT ada di daftar aset yang diperdagangkan. USDC: **(belum terverifikasi)** apakah ada di Daftar Aset Keuangan Digital.
- POJK khusus stablecoin ditargetkan Januari 2027 [(Investortrust)](https://investortrust.id/market/118744/pojk-stablecoin-terbit-januari-2027-begini-kabar-terbaru-dari-ojk-termasuk-soal-rupiah-digital).
- Sandbox: IDRP (PT Adhyoka Berkah Maju) dilaporkan lulus sebagai model penerbit stablecoin rupiah, 11 Jun 2026 **(belum terverifikasi; daftar sandbox OJK April 2026 masih mencatat "dalam uji coba")**. Lulus sandbox tidak sama dengan izin.
- OJK, 18 Nov 2026: stablecoin bukan pengganti rupiah, OJK dan BI sedang merumuskan aturannya. [Investortrust](https://investortrust.id/market/122980/aturan-stablecoin-masih-dimatangkan-ojk-tegaskan-bukan-jadi-pengganti-rupiah)

### Pajak (PMK 50/2025, berlaku 1 Agu 2025)

- PPh 22 final **0,21%** dari nilai penjualan atau tukar kripto, dipungut PAKD.
- Penyerahan kripto tidak dikenai PPN. Jasa platform kena PPN atas komisi.
- [PMK 50/2025](https://jdih.kemenkeu.go.id/api/download/d58951f3-f2a4-4e40-adcd-9b589d619adb/50%20Tahun%202025.pdf)

### Travel rule (SEOJK 16/SEOJK.07/2025, berlaku 3 Jul 2025)

- Transfer **USD1.000 ke atas**: data lengkap pengirim dan penerima (nama, alamat wallet, alamat, dokumen identitas).
- Di bawah USD1.000: cukup nama dan alamat wallet kedua pihak.
- PAKD wajib punya sistem KYT (Know Your Transaction).

## 5. Kripto di jalur pembayaran

- **UU 7/2011 Pasal 21:** rupiah wajib dipakai untuk setiap transaksi pembayaran di Indonesia.
- **PBI 10/2025 Pasal 119 ayat (1):** PSP dilarang menerima virtual currency sebagai sumber dana, memprosesnya, dan **mengaitkannya** dengan pemrosesan transaksi pembayaran. Penjelasannya memberi contoh Bitcoin, Ripple, dan **IDRT** (stablecoin rupiah).
- **Pasal 119 ayat (2):** PSP dilarang memfasilitasi perdagangan kripto, kecuali diatur aturan lain.
- **PADG 32/2025 Pasal 47:** virtual currency tidak memenuhi unsur sumber dana.
- Jalur resmi untuk remitansi berbasis stablecoin **belum ada**. Project Garuda (Rupiah Digital) masih uji coba, dan BI menyebut Rupiah Digital bukan stablecoin.

## 6. Model remitansi stablecoin di dunia

**Pola umum:** fiat pengirim → stablecoin (on-ramp di negara asal) → transfer on-chain → stablecoin → mata uang lokal (off-ramp di negara tujuan) → dibayar ke rekening, e-wallet, atau tunai.

**Yang konsisten di semua contoh: izin dipisah per langkah.** Kripto diurus exchange atau VASP berizin. Pembayaran ke penerima diurus lembaga transfer uang atau e-money berizin di negara penerima. Stablecoin hanya dipakai sebagai "pipa" di tengah.

| Pemain | Model | Izin | Koridor |
|---|---|---|---|
| MoneyGram | Tunai ↔ USDC di Stellar, cash-out di agen | Izin transfer uang MoneyGram | Global. Aplikasi stablecoin mulai AS→Kolombia [(Blockworks)](https://blockworks.co/news/moneygram-stablecoin-app-colombia) |
| Western Union | Stablecoin sendiri (USDPT) di Solana, live Mei 2026 | Diterbitkan Anchorage (bank trust AS) | Bolivia, Filipina, rencana 40+ negara [(The Block)](https://theblock.co/post/399890/western-union-launches-usdpt-stablecoin-anchorage-solana) |
| Bitso | Exchange sebagai off-ramp AS→Meksiko, ±US$6,5 miliar (2024) | Izin di Meksiko dan El Salvador | AS→Meksiko [(Decrypt)](https://decrypt.co/381988/anchorage-custody-backbone-us-mexico-stablecoin-corridor) |
| Coins.ph | Off-ramp ke peso. Izin remitansi dipegang mitra (BCRemit) | VASP + EMI dari bank sentral Filipina | Luar negeri→Filipina [(Coingeek)](https://coingeek.com/coins-ph-and-bcremit-tie-up-for-fast-affordable-money-transfers-from-filipinos-abroad) |
| Circle Payments Network | Jaringan B2B antar lembaga berizin pakai USDC | Tiap anggota pakai izinnya sendiri | LatAm, Asia Pasifik [(Circle)](https://circle.com/blog/circle-payments-network-partners-alfred-and-tazapay-supercharge-seamless-money-movement-across-latin-america-and-asia-pacific) |
| SBI Remit → Indonesia | XRP real-time per transaksi, payout lokal oleh Tranglo | Izin Jepang + mitra payout | Jepang→Indonesia, diumumkan 2023 [(Cointelegraph)](https://cointelegraph.com/news/ripple-sbi-expands-ripple-remittance-tech-to-vietnam-indonesia-and-philippines). Masih aktif atau tidak: **(belum terverifikasi)** |

**Pre-funding vs konversi saat itu juga:**
- **Pre-funding** (rupiah sudah ditaruh di muka): payout instan, tapi modal tertahan dan ada risiko kurs. Visa Direct sudah menerima pre-funding dalam USDC. [Visa](https://corporate.visa.com/en/sites/visa-perspectives/newsroom/visa-direct-moves-stablecoin-pilots-production.html)
- **Just-in-time** (kripto dijual per transaksi): modal ringan, tapi bergantung kedalaman pasar dan ada risiko harga bergeser.

### Indonesia

- **Belum ditemukan** kerja sama resmi antara PJP remitansi berizin dan exchange kripto untuk remitansi masuk, maupun pilot BI untuk remitansi stablecoin.
- Yang masih wacana: IDRX memperkenalkan stablecoin rupiah untuk remitansi PMI [(Bisnis)](https://market.bisnis.com/read/20260703/94/1985487/stablecoin-rupiah-idrx-dibidik-jadi-infrastruktur-pembayaran-lintas-negara). Pintu, Tokocrypto, Indodax, dan Triv mendorong stablecoin rupiah untuk remitansi [(Investortrust)](https://investortrust.id/indepth/76445/stablecoin-rupiah-solusi-efisiensi-remitansi-pmi-hingga-jaga-kedaulatan-finansial).
- Rute fiat yang sudah jalan: Nium terdaftar di BI sebagai penyelenggara transfer dana, payout ke bank, OVO, GoPay. [Nium](https://playbook.nium.com/country/indonesia)

### Negara asal PMI: bisakah pekerja membeli stablecoin?

| Negara | Status |
|---|---|
| Jepang | **Bisa.** SBI VC Trade terdaftar untuk USDC sejak 4 Mar 2025 [(The Block)](https://www.theblock.co/post/344406/japans-sbi-vc-trade-completes-regulatory-registration-to-process-usdc-transactions) |
| Malaysia | Kemungkinan bisa, ada 5 exchange terdaftar di SC [(daftar SC)](https://www.sc.com.my/regulation/guidelines/recognizedmarkets/list-of-registered-digital-asset-exchanges). Stablecoin boleh atau tidak: **(belum terverifikasi)** |
| Hong Kong | Terbatas. Ritel hanya dari penerbit berizin HKMA, izin pertama baru April 2026 [(Gibson Dunn)](https://www.gibsondunn.com/hong-kong-va-roadmap-develops-further-through-relaxation-of-liquidity-requirements-and-increased-product-diversity/) |
| Taiwan | Transisi, UU baru disahkan [(TRM)](https://trmlabs.com/resources/blog/unpacking-taiwans-virtual-asset-service-act-what-crypto-and-stablecoin-issuers-need-to-know) |
| Korea Selatan | Praktis sulit, butuh rekening bank atas nama asli. Dari ±566 ribu akun WNA, hanya 90 aktif [(Korea Times)](https://www.koreatimes.co.kr/economy/cryptocurrency/20260823/560000-foreign-nationals-have-korean-crypto-accounts-but-just-90-are-active) |
| Arab Saudi | **Tidak ada jalur berizin** untuk ritel [(VLO)](https://vlolawfirm.com/trackers/crypto-regulation-saudi-arabia) |

Dua koridor terbesar (Malaysia dan Arab Saudi) justru yang paling tidak jelas atau tertutup untuk stablecoin. Jepang paling siap tapi volumenya kecil.

### Risiko yang terlihat

- **Depeg:** USDC sempat ke ±US$0,88 pada 11 Mar 2023 karena cadangan tertahan di SVB, pulih 13 Mar. [S&P](https://spglobal.com/ratings/en/research/articles/230315-stablecoin-depegging-highlights-defi-s-exposure-to-tradfi-risks-12669023)
- **Biaya on-ramp di negara asal** sering jadi titik termahal dan tersulit untuk pekerja.
- **Bank menolak nasabah terkait kripto (de-risking)** **(belum terverifikasi untuk kasus Indonesia)**.

---

## Yang langsung relevan ke PJT (temuan, belum pemetaan)

- Alur PJT sekarang (pembayar → USDC ke akun PT → PT jual ke rupiah → bayar merchant) menabrak dua aturan sekaligus kalau dijalankan untuk publik:
  - **OJK:** PT membeli USDC dari banyak orang sebagai usaha = kegiatan PAKD tanpa izin (POJK 23/2025 Pasal 51, UU 4/2026 Pasal 304A).
  - **BI:** kalau PT juga jadi penyelenggara pembayaran/remitansi, ia dilarang menerima atau mengaitkan virtual currency (PBI 10/2025 Pasal 119).
- Pola yang dipakai pemain dunia: **pihak berizin kripto (di Indonesia: PAKD seperti Indodax) mengurus kripto, pihak berizin pembayaran (PJP) mengurus rupiah.** Apakah pemisahan itu cukup untuk lolos dari larangan "mengaitkan" di Pasal 119 belum ada jawabannya. Harus ditanya ke BI atau konsultan hukum.
- Untuk remitansi masuk, jalur paling realistis dari sisi negara asal adalah **Jepang**. Dua koridor terbesar (Malaysia, Arab Saudi) belum jelas atau tertutup untuk stablecoin.

## Yang belum pasti

1. Apakah pemisahan PAKD (kripto) dan PJP (rupiah) lolos dari larangan "mengaitkan" di PBI 10/2025 Pasal 119. **Ini pertanyaan paling menentukan.** Saluran OJK: sprint.corner@ojk.go.id.
2. USDC ada atau tidak di Daftar Aset Keuangan Digital (cek di cfx.co.id).
3. Aturan turunan UU 4/2026, termasuk Pasal 221A ayat (8) soal wajib lewat atau lapor ke bursa.
4. Isi POJK stablecoin (target Januari 2027).
5. Status sandbox IDRP dan IDRX.
6. Biaya per koridor terbaru dari World Bank (situsnya menolak akses otomatis, perlu dibuka manual).
7. Ambang nominal travel rule di aturan BI (PBI 10/2024, PADG 15/2025) dan nomor peraturan PPATK untuk laporan IFTI.
8. Apakah layanan SBI Remit → Indonesia (XRP + Tranglo) masih aktif.
9. Akses stablecoin untuk pekerja di Malaysia, Hong Kong, dan Taiwan.

**Catatan perbedaan antar sumber:** beberapa sumber sekunder mengutip larangan virtual currency dari PBI 23/6/PBI/2021 (Pasal 202–204) atau PBI 22/23/PBI/2020 Pasal 73. PBI 22/23/2020 sudah dicabut. Rujukan yang berlaku sekarang adalah **PBI 10/2025 Pasal 119**.

---

## 7. Tipe negara terhadap kripto (24 Nov 2026)

Dipakai untuk memilih jalur tiap koridor di modul remitansi (`apps/api/src/remit/corridors.ts`). Sebagian besar sumber dari firma hukum atau media sekunder. Sumber dari regulator langsung: BI, SC Malaysia, HKMA, MAS, FSA, dan FCA.

| Tipe | Arti | Jalur |
|---|---|---|
| A | Teregulasi, ritel bisa beli/jual stablecoin dan tarik ke bank lokal | Kripto end-to-end lewat exchange berizin |
| B | Legal tapi dibatasi (stablecoin terbatas, WNA sulit onboarding, masa transisi) | USDC hanya antar lembaga berizin; pengguna memakai uang lokal |
| C | Belum ada kerangka atau venue berizin | Fiat saja |
| D | Dilarang | Fiat saja; USDC tidak menyentuh negara itu |

| Negara | Tipe | Remitansi ke RI 2025 (juta USD) | Alasan singkat |
|---|---|---|---|
| Malaysia | B | 4.772 | Exchange berizin SC ada, USDC/USDT untuk ritel belum terbukti disetujui (belum terverifikasi) |
| Arab Saudi | C (mendekati D) | 3.991 | Tidak ada exchange berizin untuk ritel; sumber saling bertentangan "ilegal" vs "tidak diatur" |
| Taiwan | A (transisi) | 2.972 | Exchange terdaftar FSC; UU VASP disahkan 30 Jun 2026, tanggal berlaku belum ada |
| Hong Kong | B | 2.634 | Ritel hanya stablecoin penerbit berizin HKMA; USDC/USDT tidak dibuka |
| Korea Selatan | B | 716 | Pekerja asing praktis tidak bisa membuka akun real-name |
| Jepang | A | 651 | SBI VC Trade terdaftar FSA untuk USDC |
| Singapura | A | 479 | Exchange berizin MAS; aturan stablecoin sedang dikonsultasikan |
| UEA | B | 152 | Stablecoin asing dibatasi di mainland; free zone lebih longgar |
| Brunei | C | 60 | Bank sentral menyebut kripto di luar pengawasannya |
| Qatar | D | 31 | QCB melarang layanan kripto sejak 2018 |
| Kuwait | D | 59 | Larangan total sejak Juli 2023 (belum masuk modul) |

Volume dari [BI SEKI V.31](https://www.bi.go.id/seki/tabel/TABEL5_31.pdf), angka 2025 sementara.

**Implikasi:** dari 6 koridor terbesar (±91% remitansi ke RI), hanya Taiwan dan Jepang yang realistis memakai kripto end-to-end untuk pekerja. Dua terbesar, Malaysia dan Arab Saudi, harus lewat B2B atau fiat.

**Yang belum pasti:** daftar aset SC Malaysia untuk USDT/USDC; tanggal berlaku UU VASP Taiwan dan KYC pekerja ber-ARC; apakah lembaga remitansi Korea boleh settle pakai USDC; status final Arab Saudi dari dokumen SAMA/CMA.
