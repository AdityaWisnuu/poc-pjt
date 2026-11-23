import { crc16Ccitt, parseQris, QrisError } from './qris';

const tlv = (tag: string, value: string) =>
  `${tag}${String(value.length).padStart(2, '0')}${value}`;

function build(extra: Record<string, string> = {}, omit: string[] = []) {
  const fields: Record<string, string> = {
    '00': '01',
    '01': '12',
    '26': tlv('00', 'ID.CO.QRIS.WWW') + tlv('01', '936000000000000001'),
    '52': '5812',
    '53': '360',
    '54': '25000',
    '58': 'ID',
    '59': 'Kopi Klaten',
    '60': 'KLATEN',
    ...extra,
  };
  const body = Object.keys(fields)
    .filter((tag) => !omit.includes(tag))
    .sort()
    .map((tag) => tlv(tag, fields[tag]))
    .join('');
  const unsigned = `${body}6304`;
  return unsigned + crc16Ccitt(unsigned);
}

describe('parseQris', () => {
  it('computes the standard CRC-16/CCITT-FALSE check value', () => {
    expect(crc16Ccitt('123456789')).toBe('29B1');
  });

  it('reads merchant and amount from a dynamic QR', () => {
    expect(parseQris(build())).toMatchObject({
      isDynamic: true,
      merchantName: 'Kopi Klaten',
      merchantCity: 'KLATEN',
      amountIdr: 25000,
    });
  });

  it('returns null amount for a static QR', () => {
    const parsed = parseQris(build({ '01': '11' }, ['54']));
    expect(parsed.isDynamic).toBe(false);
    expect(parsed.amountIdr).toBeNull();
  });

  it('adds fixed and percentage tips', () => {
    expect(parseQris(build({ '55': '02', '56': '1000' })).amountIdr).toBe(26000);
    expect(parseQris(build({ '55': '03', '57': '10' })).amountIdr).toBe(27500);
  });

  it('rounds fractional rupiah up so the merchant is never short', () => {
    expect(parseQris(build({ '54': '25000.50' })).amountIdr).toBe(25001);
  });

  it('rejects a tampered QR', () => {
    const qr = build();
    const tampered = qr.replace('25000', '10000');
    expect(() => parseQris(tampered)).toThrow(QrisError);
  });

  it('rejects non-rupiah and non-QRIS payloads', () => {
    expect(() => parseQris(build({ '53': '840' }))).toThrow(QrisError);
    expect(() =>
      parseQris(build({ '26': tlv('00', 'COM.EXAMPLE.PAY') })),
    ).toThrow(QrisError);
    expect(() => parseQris('https://example.com')).toThrow(QrisError);
  });
});
