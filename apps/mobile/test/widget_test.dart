import 'package:flutter_test/flutter_test.dart';
import 'package:pjt/theme.dart';

void main() {
  test('formats rupiah and USDC in Indonesian notation', () {
    expect(rupiah(25000), 'Rp25.000');
    expect(usdc('1.381259'), '1,3813');
    expect(tokenAmount('USDT', '1.381259'), '1,3813');
    expect(tokenAmount('IDRX', '25000'), '25.000');
  });

  test('shows payment time in WIB', () {
    expect(
      wibTime(DateTime.utc(2026, 11, 23, 9, 48, 30)),
      '23 Nov 2026, 16.48.30 WIB',
    );
  });
}
