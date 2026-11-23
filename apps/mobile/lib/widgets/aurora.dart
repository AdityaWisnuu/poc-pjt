import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

/// Living gradient behind the balance. Energy rises while money is moving.
class Aurora extends StatefulWidget {
  const Aurora({super.key, this.energy = 0, this.success = 0});

  final double energy;
  final double success;

  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram>? _program;

  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _program ??= ui.FragmentProgram.fromAsset('shaders/aurora.frag');
    _program!.then((program) {
      if (mounted) setState(() => _shader = program.fragmentShader());
    });
    _ticker = createTicker((elapsed) {
      _time.value = 40 + elapsed.inMilliseconds / 1000;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) return const ColoredBox(color: Palette.ink);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.energy),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      builder: (_, energy, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: widget.success),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (_, success, _) => RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _AuroraPainter(shader, _time, energy, success),
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.shader, this.time, this.energy, this.success)
    : super(repaint: time);

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final double energy;
  final double success;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, energy)
      ..setFloat(4, success);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.energy != energy || old.success != success || old.shader != shader;
}
