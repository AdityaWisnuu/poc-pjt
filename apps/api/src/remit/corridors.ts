/**
 * How a corridor moves value. Picked from the country's stance on crypto,
 * never from convenience.
 * - crypto: people on that side buy or sell USDC at a licensed local venue.
 * - b2b:    people only see local money; licensed institutions settle in USDC.
 * - fiat:   crypto is not used at all on that side; a licensed money transfer
 *           partner pays from pre-funded money and settles later by bank wire.
 */
export type Rail = 'crypto' | 'b2b' | 'fiat';

/** A: regulated and open to retail. B: legal but restricted. C: no framework. D: prohibited. */
export type CountryType = 'A' | 'B' | 'C' | 'D';

export interface Bank {
  code: string;
  name: string;
}

export interface SampleAccount {
  bank: string;
  account: string;
  name: string;
}

export interface Corridor {
  code: string;
  country: string;
  currency: string;
  type: CountryType;
  typeLabel: string;
  rail: Rail;
  /** One line shown to the operator: why this rail. */
  reason: string;
  /** Licensed party abroad that handles that side (simulated in this PoC). */
  partner: string;
  /** Domestic payment system the partner pays out through. */
  payoutChannel: string;
  /** 2025 remittance to Indonesia, million USD (BI SEKI V.31). */
  volume2025: number;
  banks: Bank[];
  samples: SampleAccount[];
}

export const TYPE_LABELS: Record<CountryType, string> = {
  A: 'Teregulasi, terbuka untuk ritel',
  B: 'Legal, tapi dibatasi',
  C: 'Belum ada kerangka',
  D: 'Dilarang',
};

/** Simulated partner margin per rail. An assumption, not a quoted price. */
export const PARTNER_SPREAD: Record<Rail, string> = {
  crypto: '0.005',
  b2b: '0.008',
  fiat: '0.02',
};

/** Which rail each country type allows. B keeps crypto between licensed institutions only. */
export const RAIL_BY_TYPE: Record<CountryType, Rail> = {
  A: 'crypto',
  B: 'b2b',
  C: 'fiat',
  D: 'fiat',
};

const make = (c: Omit<Corridor, 'typeLabel' | 'rail'>): Corridor => ({
  ...c,
  typeLabel: TYPE_LABELS[c.type],
  rail: RAIL_BY_TYPE[c.type],
});

/**
 * Classification from the country research of 24 Nov 2026
 * (docs/riset/remitansi-dan-kripto.md). Volume is 2025 remittance to
 * Indonesia in million USD, BI SEKI table V.31 (provisional figures).
 */
export const CORRIDORS: Corridor[] = [
  make({
    code: 'MY',
    country: 'Malaysia',
    currency: 'MYR',
    type: 'B',
    volume2025: 4772,
    reason:
      'Exchange berizin SC ada, tapi USDC/USDT untuk ritel belum terbukti disetujui',
    partner: 'Lembaga remitansi berizin BNM',
    payoutChannel: 'DuitNow',
    banks: [
      { code: 'MBB', name: 'Maybank' },
      { code: 'CIMB', name: 'CIMB Bank' },
      { code: 'PBB', name: 'Public Bank' },
    ],
    samples: [
      { bank: 'MBB', account: '114012345678', name: 'NUR AISYAH BINTI AHMAD' },
    ],
  }),
  make({
    code: 'SA',
    country: 'Arab Saudi',
    currency: 'SAR',
    type: 'C',
    volume2025: 3991,
    reason:
      'Tidak ada exchange kripto berizin untuk ritel; peringatan SAMA/CMA masih berlaku',
    partner: 'Money transfer berizin SAMA',
    payoutChannel: 'SARIE',
    banks: [
      { code: 'RJHI', name: 'Al Rajhi Bank' },
      { code: 'SNB', name: 'Saudi National Bank' },
    ],
    samples: [
      { bank: 'RJHI', account: '608010167519', name: 'FATIMAH AL HARBI' },
    ],
  }),
  make({
    code: 'TW',
    country: 'Taiwan',
    currency: 'TWD',
    type: 'A',
    volume2025: 2972,
    reason: 'Exchange terdaftar FSC; UU VASP disahkan Jun 2026, masih transisi',
    partner: 'Exchange terdaftar FSC',
    payoutChannel: 'FISC',
    banks: [
      { code: '013', name: 'Cathay United Bank' },
      { code: '822', name: 'CTBC Bank' },
      { code: '700', name: 'Chunghwa Post' },
    ],
    samples: [{ bank: '013', account: '013501234567', name: 'CHEN MEI LING' }],
  }),
  make({
    code: 'HK',
    country: 'Hong Kong',
    currency: 'HKD',
    type: 'B',
    volume2025: 2634,
    reason:
      'Ritel hanya boleh stablecoin penerbit berizin HKMA; USDC/USDT tidak dibuka',
    partner: 'Money service operator berizin',
    payoutChannel: 'FPS',
    banks: [
      { code: '004', name: 'HSBC' },
      { code: '012', name: 'Bank of China (HK)' },
      { code: '003', name: 'Standard Chartered HK' },
    ],
    samples: [{ bank: '004', account: '123456789001', name: 'WONG KA YAN' }],
  }),
  make({
    code: 'KR',
    country: 'Korea Selatan',
    currency: 'KRW',
    type: 'B',
    volume2025: 716,
    reason:
      'Exchange ada, tapi pekerja asing praktis tidak bisa membuka akun real-name',
    partner: 'Lembaga remitansi berizin',
    payoutChannel: 'Transfer bank domestik',
    banks: [
      { code: '004', name: 'KB Kookmin Bank' },
      { code: '088', name: 'Shinhan Bank' },
      { code: '020', name: 'Woori Bank' },
    ],
    samples: [{ bank: '088', account: '110123456789', name: 'KIM MIN JI' }],
  }),
  make({
    code: 'JP',
    country: 'Jepang',
    currency: 'JPY',
    type: 'A',
    volume2025: 651,
    reason: 'Exchange terdaftar FSA melayani USDC untuk penduduk, termasuk WNA',
    partner: 'Exchange terdaftar FSA',
    payoutChannel: 'Zengin',
    banks: [
      { code: '0005', name: 'MUFG Bank' },
      { code: '0009', name: 'SMBC' },
      { code: '0001', name: 'Mizuho Bank' },
      { code: '9900', name: 'Japan Post Bank' },
    ],
    samples: [
      { bank: '0005', account: '0011234567', name: 'TANAKA HARUKI' },
      { bank: '9900', account: '1234567890', name: 'SATO YUMI' },
    ],
  }),
  make({
    code: 'SG',
    country: 'Singapura',
    currency: 'SGD',
    type: 'A',
    volume2025: 479,
    reason:
      'Exchange berizin MAS melayani ritel; aturan stablecoin sedang dikonsultasikan',
    partner: 'Exchange berizin MAS',
    payoutChannel: 'FAST',
    banks: [
      { code: '7171', name: 'DBS' },
      { code: '7339', name: 'OCBC' },
      { code: '7375', name: 'UOB' },
    ],
    samples: [{ bank: '7171', account: '0721234567', name: 'TAN WEI MING' }],
  }),
  make({
    code: 'AE',
    country: 'Uni Emirat Arab',
    currency: 'AED',
    type: 'B',
    volume2025: 152,
    reason:
      'Stablecoin asing dibatasi di mainland; hanya free zone (VARA/ADGM) yang longgar',
    partner: 'Exchange house berizin CBUAE',
    payoutChannel: 'UAEFTS',
    banks: [
      { code: 'ENBD', name: 'Emirates NBD' },
      { code: 'FAB', name: 'First Abu Dhabi Bank' },
    ],
    samples: [
      { bank: 'ENBD', account: '1012345678901', name: 'AHMED AL MANSOORI' },
    ],
  }),
  make({
    code: 'BN',
    country: 'Brunei',
    currency: 'BND',
    type: 'C',
    volume2025: 60,
    reason:
      'Bank sentral menyebut kripto di luar pengawasannya; belum ada kerangka',
    partner: 'Remitansi berizin BDCB',
    payoutChannel: 'Transfer bank domestik',
    banks: [
      { code: 'BIBD', name: 'BIBD' },
      { code: 'BAID', name: 'Baiduri Bank' },
    ],
    samples: [
      { bank: 'BIBD', account: '00011012345678', name: 'NURUL HIDAYAH' },
    ],
  }),
  make({
    code: 'QA',
    country: 'Qatar',
    currency: 'QAR',
    type: 'D',
    volume2025: 31,
    reason:
      'QCB melarang layanan kripto sejak 2018; stablecoin tidak diizinkan',
    partner: 'Exchange house berizin QCB',
    payoutChannel: 'Transfer bank domestik',
    banks: [
      { code: 'QNB', name: 'QNB' },
      { code: 'CBQ', name: 'Commercial Bank of Qatar' },
    ],
    samples: [
      { bank: 'QNB', account: '0012345678901', name: 'KHALID AL THANI' },
    ],
  }),
];

export const ID_BANKS: Bank[] = [
  { code: '014', name: 'BCA' },
  { code: '002', name: 'BRI' },
  { code: '008', name: 'Bank Mandiri' },
  { code: '009', name: 'BNI' },
  { code: '451', name: 'BSI' },
];

/** Demo beneficiaries the simulated Bank INA inquiry recognises. */
export const ID_SAMPLES: SampleAccount[] = [
  { bank: '014', account: '1234567890', name: 'SITI RAHAYU' },
  { bank: '002', account: '012301000123567', name: 'SLAMET RIYADI' },
  { bank: '008', account: '1370012345678', name: 'DEWI LESTARI' },
];

/** Stand-in for DTTOT and sanctions lists. Names are fictional. */
export const SANCTIONS_SAMPLE = ['BUDI CONTOHSANKSI', 'JOHN EXAMPLE BLOCKED'];

export function corridor(code: string): Corridor | undefined {
  return CORRIDORS.find((item) => item.code === code);
}
