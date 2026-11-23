import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final quote = await Api.instance.quote(
        _quote.qr,
        amountIdr: _quote.amountIdr,
      );
      if (!mounted) return;
      setState(() => _quote = quote);
      _startTimer();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
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
                  const Spacer(flex: 2),
                  Reveal(child: _merchant()),
                  const SizedBox(height: 22),
                  Reveal(
                    delay: 70,
                    child: FittedBox(
                      child: Text(
                        rupiah(_quote.amountIdr!),
                        style: type(56, weight: 700, tabular: true),
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  Reveal(delay: 140, child: _details()),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 22,
                    child: _error == null
                        ? null
                        : Text(
                            _error!,
                            style: type(
                              13.5,
                              weight: 600,
                              color: Palette.coral,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Reveal(
                    delay: 210,
                    child: expired
                        ? PrimaryButton(
                            label: _refreshing
                                ? 'Memperbarui…'
                                : 'Perbarui kurs',
                            onTap: _refreshing ? null : _refresh,
                          )
                        : SlideToPay(
                            label: 'Geser untuk bayar',
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
        width: 66,
        height: 66,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Palette.text,
          shape: BoxShape.circle,
        ),
        child: Text(
          _quote.merchantName.characters.first.toUpperCase(),
          style: type(27, weight: 800, color: Palette.ink),
        ),
      ),
      const SizedBox(height: 13),
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

  Widget _details() => Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
    decoration: BoxDecoration(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Palette.line),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const TokenIcon('USDC', size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dibayar dengan',
                    style: type(12.5, color: Palette.muted),
                  ),
                  const SizedBox(height: 2),
                  Text('USDC', style: type(15.5, weight: 700)),
                ],
              ),
            ),
            Text(
              usdc(_quote.usdcAmount!),
              style: type(19, weight: 700, tabular: true),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 13),
          child: Divider(height: 1, color: Palette.line),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kurs termasuk biaya',
              style: type(13.5, color: Palette.muted),
            ),
            Text(
              '1 USDC = ${rupiah(_quote.rate!)}',
              style: type(13.5, weight: 650, tabular: true),
            ),
          ],
        ),
      ],
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
