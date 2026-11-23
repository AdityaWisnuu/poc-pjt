import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/aurora.dart';
import '../widgets/common.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key, required this.order});

  final Order order;

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Aurora(energy: 0.6, success: 1),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  children: [
                    const Spacer(),
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: AnimatedBuilder(
                        animation: _draw,
                        builder: (_, _) => CustomPaint(
                          painter: _CheckBurstPainter(_draw.value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Reveal(
                      delay: 320,
                      child: Text(
                        'Pembayaran berhasil',
                        style: type(17, weight: 700, color: Palette.ink),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Reveal(
                      delay: 390,
                      child: FittedBox(
                        child: Text(
                          rupiah(order.amountIdr),
                          style: type(
                            54,
                            weight: 750,
                            color: Palette.ink,
                            tabular: true,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Reveal(delay: 520, child: _receipt(order)),
                    const SizedBox(height: 14),
                    Reveal(
                      delay: 620,
                      child: Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Palette.ink,
                            borderRadius: BorderRadius.circular(29),
                          ),
                          child: Text('Selesai', style: type(16, weight: 700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receipt(Order order) => Container(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
    decoration: BoxDecoration(
      color: Palette.ink.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        _line('Merchant', order.merchantName),
        _line('Dibayar', '${usdc(order.usdcAmount)} USDC'),
        _line('Waktu', wibTime(order.completedAt ?? order.createdAt)),
        _line('ID', order.id.substring(order.id.length - 12).toUpperCase()),
      ],
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Text(label, style: type(13.5, color: Palette.muted)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type(13.5, weight: 650, tabular: true),
          ),
        ),
      ],
    ),
  );
}

class _CheckBurstPainter extends CustomPainter {
  const _CheckBurstPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final disc = Curves.elasticOut.transform((t / 0.62).clamp(0, 1));

    final burst = Curves.easeOutCubic.transform(((t - 0.08) / 0.8).clamp(0, 1));
    for (var i = 0; i < 16; i++) {
      final angle = math.pi * 2 * i / 16 + 0.2;
      final reach = i.isEven ? 92.0 : 76.0;
      final from = 54 + (reach - 54) * burst;
      final to = from + 15 * (1 - burst);
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * from,
        center + direction * to,
        Paint()
          ..color = Palette.ink.withValues(alpha: (1 - burst).clamp(0, 1))
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(center, 56 * disc, Paint()..color = Palette.ink);

    final check = Curves.easeInOutCubic.transform(
      ((t - 0.24) / 0.36).clamp(0, 1),
    );
    if (check > 0) {
      final path = Path()
        ..moveTo(center.dx - 23, center.dy + 1)
        ..lineTo(center.dx - 6, center.dy + 18)
        ..lineTo(center.dx + 25, center.dy - 17);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * check),
        Paint()
          ..color = Palette.mint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckBurstPainter old) => old.t != t;
}
