import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/aurora.dart';
import '../widgets/common.dart';
import '../widgets/slide_to_pay.dart';
import 'processing.dart';

class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.quote});

  final Quote quote;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  static const _ttl = 30.0;

  late Quote _quote = widget.quote;
  Timer? _timer;
  double _remaining = _ttl;
  bool _refreshing = false;
  String? _pendingAsset;
  int _requestId = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    final left =
        _quote.expiresAt!.difference(DateTime.now()).inMilliseconds / 1000;
    if (!mounted) return;
    setState(() => _remaining = left.clamp(0, _ttl));
    if (left <= 0) _timer?.cancel();
  }

  Future<void> _refresh([String? asset]) async {
    final target = asset ?? _quote.asset!;
    final request = ++_requestId;
    setState(() {
      _refreshing = true;
      _pendingAsset = target;
      _error = null;
    });
    try {
      final quote = await Api.instance.quote(
        _quote.qr,
        amountIdr: _quote.amountIdr,
        asset: target,
      );
      if (!mounted || request != _requestId) return;
      setState(() => _quote = quote);
      _startTimer();
    } on ApiException catch (error) {
      if (mounted && request == _requestId) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && request == _requestId) {
        setState(() {
          _refreshing = false;
          _pendingAsset = null;
        });
      }
    }
  }

  void _select(PaymentOption option) {
    if (option.blocked != null) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (option.asset == (_pendingAsset ?? _quote.asset)) return;
    HapticFeedback.selectionClick();
    _refresh(option.asset);
  }

  Future<void> _pay() async {
    try {
      final order = await Api.instance.pay(_quote.quoteId!);
      _timer?.cancel();
      if (!mounted) return;
      await Navigator.of(
        context,
      ).pushReplacement(fadeRoute(ProcessingScreen(order: order)));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final expired = _remaining <= 0;
    final message =
        _error ??
        (_refreshing
            ? null
            : _quote.blocked != null
            ? '${_quote.asset}: ${_quote.blocked}'
            : !_quote.sufficient
            ? 'Saldo ${_quote.asset} tidak cukup'
            : null);

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height * 0.56,
            child: const Aurora(energy: 0.25),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      _Countdown(remaining: _remaining, total: _ttl),
                    ],
                  ),
                  const Spacer(),
                  Reveal(child: _merchant()),
                  const SizedBox(height: 12),
                  Reveal(
                    delay: 70,
                    child: FittedBox(
                      child: Text(
                        rupiah(_quote.amountIdr!),
                        style: type(52, weight: 700, tabular: true),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Reveal(delay: 140, child: _assetPicker()),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 22,
                    child: message == null
                        ? null
                        : Text(
                            message,
                            style: type(
                              13.5,
                              weight: 600,
                              color: Palette.coral,
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Reveal(
                    delay: 210,
                    child: expired
                        ? PrimaryButton(
                            label: _refreshing
                                ? 'Memperbarui…'
                                : 'Perbarui kurs',
                            onTap: _refreshing ? null : () => _refresh(),
                          )
                        : SlideToPay(
                            label: 'Geser untuk bayar',
                            enabled:
                                _quote.sufficient &&
                                _quote.blocked == null &&
                                !_refreshing,
                            onComplete: _pay,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _merchant() => Column(
    children: [
      Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Palette.text,
          shape: BoxShape.circle,
        ),
        child: Text(
          _quote.merchantName.characters.first.toUpperCase(),
          style: type(23, weight: 800, color: Palette.ink),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _quote.merchantName,
        textAlign: TextAlign.center,
        style: type(19, weight: 700),
      ),
      if (_quote.merchantCity.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(
          _quote.merchantCity,
          style: type(13.5, weight: 550, color: const Color(0xCCFFFFFF)),
        ),
      ],
    ],
  );

  Widget _assetPicker() {
    final selected = _pendingAsset ?? _quote.asset;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 12, 7, 7),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 11, 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bayar dengan',
                  style: type(13, weight: 650, color: Palette.muted),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _quote.asset == 'IDRX'
                        ? 'Tanpa konversi'
                        : '1 ${_quote.asset} = ${rupiah(_quote.rate!)}',
                    key: ValueKey('${_quote.asset}${_quote.rate}'),
                    style: type(12.5, weight: 650, tabular: true),
                  ),
                ),
              ],
            ),
          ),
          for (final option in _quote.options)
            _AssetOption(
              option: option,
              selected: option.asset == selected,
              onTap: () => _select(option),
            ),
        ],
      ),
    );
  }
}

class _AssetOption extends StatelessWidget {
  const _AssetOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PaymentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: selected ? Palette.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: selected
              ? Palette.mint.withValues(alpha: 0.72)
              : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: AnimatedOpacity(
        opacity: option.payable ? 1 : 0.46,
        duration: const Duration(milliseconds: 200),
        child: Row(
          children: [
            TokenIcon(option.asset, size: 36),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.asset, style: type(15, weight: 700)),
                  const SizedBox(height: 1),
                  Text(
                    option.blocked ??
                        (option.sufficient ? option.name : 'Saldo kurang'),
                    style: type(
                      12,
                      color: option.payable ? Palette.muted : Palette.coral,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              tokenAmount(option.asset, option.amount),
              style: type(17, weight: 700, tabular: true),
            ),
            const SizedBox(width: 11),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Palette.mint : Colors.transparent,
                border: Border.all(
                  color: selected ? Palette.mint : Palette.faint,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Palette.ink,
                    )
                  : null,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.remaining, required this.total});

  final double remaining;
  final double total;

  @override
  Widget build(BuildContext context) {
    final urgent = remaining <= 8;
    final color = urgent ? Palette.coral : Palette.text;
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 9, right: 14),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CustomPaint(painter: _RingPainter(remaining / total, color)),
          ),
          const SizedBox(width: 8),
          Text(
            '${remaining.ceil()}d',
            style: type(14, weight: 700, color: color, tabular: true),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.6,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
