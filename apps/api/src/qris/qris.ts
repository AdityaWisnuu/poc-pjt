export class QrisError extends Error {}

export interface ParsedQris {
  raw: string;
  isDynamic: boolean;
  merchantName: string;
  merchantCity: string;
  /** Whole rupiah including any fixed or percentage tip. Null when the payer must enter it. */
  amountIdr: number | null;
  tipPrompt: boolean;
}

export function crc16Ccitt(input: string): string {
  let crc = 0xffff;
  for (let i = 0; i < input.length; i++) {
    crc ^= input.charCodeAt(i) << 8;
    for (let bit = 0; bit < 8; bit++) {
      crc = crc & 0x8000 ? (crc << 1) ^ 0x1021 : crc << 1;
      crc &= 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

function parseTlv(payload: string): Map<string, string> {
  const tags = new Map<string, string>();
  let i = 0;
  while (i < payload.length) {
    const tag = payload.slice(i, i + 2);
    const lengthText = payload.slice(i + 2, i + 4);
    if (!/^\d{2}$/.test(tag) || !/^\d{2}$/.test(lengthText)) {
      throw new QrisError('Format QR tidak dikenali');
    }
    const length = Number(lengthText);
    const value = payload.slice(i + 4, i + 4 + length);
    if (value.length !== length) throw new QrisError('Data QR terpotong');
    tags.set(tag, value);
    i += 4 + length;
  }
  return tags;
}

function toRupiah(value: string, label: string): number {
  if (!/^\d+(\.\d{1,2})?$/.test(value)) {
    throw new QrisError(`${label} di QR tidak valid`);
  }
  const [whole, fraction = ''] = value.split('.');
  return Number(whole) + (Number(fraction.padEnd(2, '0')) > 0 ? 1 : 0);
}

export function parseQris(input: string): ParsedQris {
  const raw = input.trim();
  if (raw.length < 40 || raw.length > 1024) {
    throw new QrisError('Ini bukan kode QRIS');
  }

  const crcStart = raw.length - 4;
  if (raw.slice(crcStart - 4, crcStart) !== '6304') {
    throw new QrisError('Ini bukan kode QRIS');
  }
  if (crc16Ccitt(raw.slice(0, crcStart)) !== raw.slice(crcStart).toUpperCase()) {
    throw new QrisError('Kode QRIS rusak, coba scan ulang');
  }

  const tags = parseTlv(raw);
  if (tags.get('00') !== '01') throw new QrisError('Ini bukan kode QRIS');
  if (tags.get('53') !== '360') {
    throw new QrisError('Hanya QRIS rupiah yang didukung');
  }
  if (tags.get('58') !== 'ID') {
    throw new QrisError('Hanya QRIS Indonesia yang didukung');
  }

  const isQris = [...tags.entries()].some(([tag, value]) => {
    const n = Number(tag);
    return n >= 26 && n <= 51 && value.toUpperCase().includes('QRIS');
  });
  if (!isQris) throw new QrisError('Ini bukan kode QRIS');

  const merchantName = tags.get('59')?.trim();
  if (!merchantName) throw new QrisError('Nama merchant tidak ada di QR');

  const baseAmount = tags.has('54')
    ? toRupiah(tags.get('54')!, 'Nominal')
    : null;

  let amountIdr = baseAmount;
  const tipIndicator = tags.get('55');
  if (baseAmount !== null && tipIndicator === '02') {
    amountIdr = baseAmount + toRupiah(tags.get('56') ?? '0', 'Tip');
  }
  if (baseAmount !== null && tipIndicator === '03') {
    const percent = Number(tags.get('57') ?? '0');
    if (!Number.isFinite(percent) || percent < 0 || percent > 100) {
      throw new QrisError('Tip di QR tidak valid');
    }
    amountIdr = baseAmount + Math.ceil((baseAmount * percent) / 100);
  }

  return {
    raw,
    isDynamic: tags.get('01') === '12',
    merchantName,
    merchantCity: tags.get('60')?.trim() ?? '',
    amountIdr,
    tipPrompt: tipIndicator === '01',
  };
}
