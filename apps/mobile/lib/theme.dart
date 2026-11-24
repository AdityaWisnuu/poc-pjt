import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

abstract final class Palette {
  static const ink = Color(0xFF07080C);
  static const surface = Color(0xFF13151C);
  static const surfaceHigh = Color(0xFF1D2029);
  static const line = Color(0x14FFFFFF);
  static const text = Color(0xFFF6F7F9);
  static const muted = Color(0xFF9398A6);
  static const faint = Color(0xFF5E6371);
  static const mint = Color(0xFF22EDB3);
  static const coral = Color(0xFFFF6645);
  static const cobalt = Color(0xFF1A40FA);
}

TextStyle type(
  double size, {
  double weight = 500,
  Color color = Palette.text,
  double? spacing,
  double? height,
  bool tabular = false,
}) {
  return TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: size,
    fontVariations: [FontVariation('wght', weight)],
    color: color,
    letterSpacing: spacing ?? (size >= 28 ? -size * 0.035 : -0.1),
    height: height,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Palette.ink,
    fontFamily: 'PlusJakartaSans',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      primary: Palette.text,
      secondary: Palette.mint,
      surface: Palette.surface,
      error: Palette.coral,
    ),
  );
}

final _rupiah = NumberFormat('#,##0', 'id');
final _usdc = NumberFormat('#,##0.0000', 'id');

String rupiah(num value) => 'Rp${_rupiah.format(value)}';
String plainNumber(num value) => _rupiah.format(value);
String usdc(String value) => _usdc.format(double.parse(value));
String tokenAmount(String asset, String value) =>
    asset == 'IDRX' ? plainNumber(num.parse(value)) : usdc(value);

const _symbols = {
  'IDR': 'Rp',
  'JPY': '¥',
  'KRW': '₩',
  'MYR': 'RM',
  'TWD': r'NT$',
  'HKD': r'HK$',
  'SGD': r'S$',
  'BND': r'B$',
};

/// Formats an amount string from the API in its own currency.
String money(String value, String currency) {
  final number = num.parse(value);
  if (currency == 'USDC') return '${usdc(value)} USDC';
  final whole = const ['IDR', 'JPY', 'KRW'].contains(currency);
  final text = NumberFormat(whole ? '#,##0' : '#,##0.00', 'id').format(number);
  final symbol = _symbols[currency];
  return symbol == null ? '$currency $text' : '$symbol$text';
}

String wibTime(DateTime value) {
  final wib = value.toUtc().add(const Duration(hours: 7));
  return '${DateFormat('d MMM yyyy, HH.mm.ss', 'en_US').format(wib)} WIB';
}

String shortTime(DateTime value) {
  final wib = value.toUtc().add(const Duration(hours: 7));
  return '${DateFormat('d MMM, HH.mm', 'en_US').format(wib)} WIB';
}

Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
