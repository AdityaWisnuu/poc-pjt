import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'amount.dart';
import 'confirm.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.isSimulation});

  final bool isSimulation;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  bool _busy = false;
  bool _torch = false;
  String? _message;

  @override
  void dispose() {
    _sweep.dispose();
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (value != null) _resolve(value);
  }

  Future<void> _useSample() async {
    if (_busy) return;
    try {
      _resolve(await Api.instance.sampleQr());
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    }
  }

  Future<void> _resolve(String qr) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final quote = await Api.instance.quote(qr);
      if (!mounted) return;
      await _camera.stop();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        fadeRoute(
          quote.needsAmount
              ? AmountScreen(quote: quote)
              : ConfirmScreen(quote: quote),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _message = error.message);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final side = size.width * 0.72;
    final window = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.44),
      width: side,
      height: side,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (_, _) => _cameraError(),
          ),
          AnimatedBuilder(
            animation: _sweep,
            builder: (_, _) => CustomPaint(
              painter: _ViewfinderPainter(
                window: window,
                sweep: Curves.easeInOut.transform(_sweep.value),
                locked: _busy && _message == null,
                failed: _message != null,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoundIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  RoundIconButton(
                    icon: _torch
                        ? Icons.flashlight_on_rounded
                        : Icons.flashlight_off_rounded,
                    onTap: () {
                      _camera.toggleTorch();
                      setState(() => _torch = !_torch);
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: window.bottom + 28,
            left: 32,
            right: 32,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                _message ??
                    (_busy ? 'Membaca QRIS…' : 'Arahkan kamera ke kode QRIS'),
                key: ValueKey(_message ?? _busy),
                textAlign: TextAlign.center,
                style: type(
                  15.5,
                  weight: 650,
                  color: _message != null ? Palette.coral : Palette.text,
                ),
              ),
            ),
          ),
          if (widget.isSimulation)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 26,
              child: Center(
                child: Pressable(
                  onTap: _busy ? null : _useSample,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Pakai QRIS contoh',
                      style: type(14.5, weight: 700, color: Palette.mint),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cameraError() => ColoredBox(
    color: Palette.ink,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Kamera belum diizinkan. Aktifkan di Pengaturan.',
          textAlign: TextAlign.center,
          style: type(15, color: Palette.muted),
        ),
      ),
    ),
  );
}

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({
    required this.window,
    required this.sweep,
    required this.locked,
    required this.failed,
  });

  final Rect window;
  final double sweep;
  final bool locked;
  final bool failed;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(window, const Radius.circular(34));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = const Color(0xB8050609),
    );

    final accent = failed
        ? Palette.coral
        : locked
        ? Palette.mint
        : Palette.text;

    if (!locked && !failed) {
      final y = window.top + 14 + (window.height - 28) * sweep;
      canvas.save();
      canvas.clipRRect(hole);
      canvas.drawRect(
        Rect.fromLTRB(window.left, y - 54, window.right, y),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Palette.mint.withValues(alpha: 0),
              Palette.mint.withValues(alpha: 0.2),
            ],
          ).createShader(Rect.fromLTRB(window.left, y - 54, window.right, y)),
      );
      canvas.drawLine(
        Offset(window.left + 16, y),
        Offset(window.right - 16, y),
        Paint()
          ..color = Palette.mint
          ..strokeWidth = 1.6,
      );
      canvas.restore();
    }

    const arm = 40.0;
    const r = 34.0;
    final stroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = window;
    final corners = Path()
      ..moveTo(w.left, w.top + arm + r)
      ..lineTo(w.left, w.top + r)
      ..arcToPoint(Offset(w.left + r, w.top), radius: const Radius.circular(r))
      ..lineTo(w.left + r + arm, w.top)
      ..moveTo(w.right - r - arm, w.top)
      ..lineTo(w.right - r, w.top)
      ..arcToPoint(Offset(w.right, w.top + r), radius: const Radius.circular(r))
      ..lineTo(w.right, w.top + r + arm)
      ..moveTo(w.right, w.bottom - r - arm)
      ..lineTo(w.right, w.bottom - r)
      ..arcToPoint(
        Offset(w.right - r, w.bottom),
        radius: const Radius.circular(r),
      )
      ..lineTo(w.right - r - arm, w.bottom)
      ..moveTo(w.left + r + arm, w.bottom)
      ..lineTo(w.left + r, w.bottom)
      ..arcToPoint(
        Offset(w.left, w.bottom - r),
        radius: const Radius.circular(r),
      )
      ..lineTo(w.left, w.bottom - r - arm);
    canvas.drawPath(corners, stroke);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) =>
      old.sweep != sweep || old.locked != locked || old.failed != failed;
}
