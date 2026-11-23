import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

class TokenIcon extends StatelessWidget {
  const TokenIcon(this.symbol, {super.key, this.size = 40});

  final String symbol;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/tokens/${symbol.toLowerCase()}.svg',
    width: size,
    height: size,
  );
}

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onTap != null) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _set(true),
    onTapCancel: () => _set(false),
    onTapUp: (_) => _set(false),
    onTap: widget.onTap == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            widget.onTap!();
          },
    child: AnimatedScale(
      scale: _down ? 0.955 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.background = const Color(0x33000000),
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 21, color: Palette.text),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedOpacity(
      opacity: onTap == null ? 0.35 : 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Palette.text,
          borderRadius: BorderRadius.circular(29),
        ),
        child: Text(label, style: type(16, weight: 700, color: Palette.ink)),
      ),
    ),
  );
}

/// Staggered entrance used across screens.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final total = 620 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (_, raw, child) {
        final start = delay / total;
        final progress = Curves.easeOutCubic.transform(
          ((raw - start) / (1 - start)).clamp(0, 1),
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.style,
    required this.format,
  });

  final num value;
  final TextStyle style;
  final String Function(num) format;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: const Duration(milliseconds: 1100),
    curve: Curves.easeOutExpo,
    builder: (_, current, _) => Text(format(current.round()), style: style),
  );
}
