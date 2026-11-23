import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class SlideToPay extends StatefulWidget {
  const SlideToPay({
    super.key,
    required this.label,
    required this.onComplete,
    this.enabled = true,
  });

  final String label;
  final Future<void> Function() onComplete;
  final bool enabled;

  @override
  State<SlideToPay> createState() => _SlideToPayState();
}

class _SlideToPayState extends State<SlideToPay> with TickerProviderStateMixin {
  static const _height = 68.0;
  static const _knob = 58.0;
  static const _inset = 5.0;

  late final AnimationController _position = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  )..repeat();

  bool _busy = false;
  bool _armed = false;

  @override
  void dispose() {
    _position.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails details, double travel) {
    if (_busy || !widget.enabled) return;
    _position.value += details.delta.dx / travel;
    final armed = _position.value >= 0.9;
    if (armed != _armed) {
      _armed = armed;
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _release() async {
    if (_busy || !widget.enabled) return;
    if (_position.value < 0.9) {
      _armed = false;
      await _position.animateTo(0, curve: Curves.easeOutBack);
      return;
    }
    setState(() => _busy = true);
    await _position.animateTo(1, curve: Curves.easeOut);
    HapticFeedback.heavyImpact();
    try {
      await widget.onComplete();
    } finally {
      if (mounted) {
        _armed = false;
        setState(() => _busy = false);
        _position.animateTo(0, curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final travel = constraints.maxWidth - _knob - _inset * 2;
        return AnimatedOpacity(
          opacity: widget.enabled ? 1 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: GestureDetector(
            onHorizontalDragUpdate: (details) => _drag(details, travel),
            onHorizontalDragEnd: (_) => _release(),
            onHorizontalDragCancel: _release,
            child: Container(
              height: _height,
              decoration: BoxDecoration(
                color: Palette.surfaceHigh,
                borderRadius: BorderRadius.circular(_height / 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: AnimatedBuilder(
                animation: Listenable.merge([_position, _shimmer]),
                builder: (_, _) {
                  final x = travel * _position.value;
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: x + _knob + _inset,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(_height / 2),
                            gradient: LinearGradient(
                              colors: [
                                Palette.cobalt.withValues(alpha: 0.2),
                                Palette.mint.withValues(
                                  alpha: 0.2 + 0.55 * _position.value,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Opacity(
                          opacity: (1 - _position.value * 1.7).clamp(0, 1),
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              final s = _shimmer.value * 3 - 1;
                              return LinearGradient(
                                begin: Alignment(s - 0.45, 0),
                                end: Alignment(s + 0.45, 0),
                                colors: const [
                                  Palette.muted,
                                  Palette.text,
                                  Palette.muted,
                                ],
                              ).createShader(bounds);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 42),
                              child: Text(
                                widget.label,
                                style: type(15.5, weight: 650),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: _inset + x,
                        child: Container(
                          width: _knob,
                          height: _knob,
                          decoration: const BoxDecoration(
                            color: Palette.text,
                            shape: BoxShape.circle,
                          ),
                          child: _busy
                              ? const Padding(
                                  padding: EdgeInsets.all(19),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Palette.ink,
                                  ),
                                )
                              : Icon(
                                  _armed
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 22,
                                  color: Palette.ink,
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
