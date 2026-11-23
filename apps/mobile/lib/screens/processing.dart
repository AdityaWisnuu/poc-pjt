import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/aurora.dart';
import '../widgets/common.dart';
import 'success.dart';

class _Stage {
  const _Stage(this.statuses, this.label, this.detail);

  final List<String> statuses;
  final String label;
  final String detail;
}

List<_Stage> _stagesFor(String asset) => [
  if (asset == 'IDRX')
    const _Stage(
      ['CREATED', 'SENDING_IDRX'],
      'Mengirim IDRX',
      'Tanpa konversi, langsung ke akun settlement',
    )
  else ...[
    _Stage(['CREATED', 'SELLING_ASSET'], 'Menjual $asset', '$asset ke rupiah'),
    const _Stage(
      ['BUYING_IDRX'],
      'Membeli IDRX',
      'Rupiah ke stablecoin rupiah',
    ),
    const _Stage(['SENDING_IDRX'], 'Mengirim IDRX', 'Ke akun settlement'),
  ],
  const _Stage(
    ['AWAITING_RECEIPT'],
    'Memastikan dana masuk',
    'Verifikasi penerimaan',
  ),
  const _Stage(['PAYING_MERCHANT'], 'Membayar merchant', 'Rupiah lewat QRIS'),
];

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.order});

  final Order order;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late Order _order = widget.order;
  late final List<_Stage> _stages = _stagesFor(widget.order.asset);
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..repeat();
  Timer? _poll;
  int _lastStage = 0;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 450), (_) => _fetch());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _spin.dispose();
    super.dispose();
  }

  int get _stage {
    if (_order.isSuccess) return _stages.length;
    final index = _stages.indexWhere((s) => s.statuses.contains(_order.status));
    return index < 0 ? _lastStage : index;
  }

  Future<void> _fetch() async {
    try {
      final order = await Api.instance.order(_order.id);
      if (!mounted) return;
      final next = order.isSuccess
          ? _stages.length
          : _stages.indexWhere((s) => s.statuses.contains(order.status));
      if (next > _lastStage) {
        _lastStage = next;
        HapticFeedback.lightImpact();
      }
      setState(() => _order = order);

      if (order.isSuccess) {
        _poll?.cancel();
        HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 520));
        if (!mounted) return;
        await Navigator.of(
          context,
        ).pushReplacement(fadeRoute(SuccessScreen(order: order)));
      } else if (order.isFailed) {
        _poll?.cancel();
        HapticFeedback.heavyImpact();
      }
    } on ApiException {
      // A dropped poll must not read as a failed payment. Keep polling.
    }
  }

  @override
  Widget build(BuildContext context) {
    final failed = _order.isFailed;
    final review = _order.status == 'NEEDS_REVIEW';

    return PopScope(
      canPop: failed,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Aurora(energy: failed ? 0 : 1),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      failed
                          ? (review ? 'Perlu dicek' : 'Pembayaran gagal')
                          : 'Memproses',
                      style: type(16, weight: 650),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      child: Text(
                        rupiah(_order.amountIdr),
                        style: type(46, weight: 700, tabular: true),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ke ${_order.merchantName}',
                      style: type(
                        15,
                        weight: 600,
                        color: const Color(0xD9FFFFFF),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                      decoration: BoxDecoration(
                        color: Palette.ink.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Palette.line),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _stages.length; i++)
                            _row(i, failed),
                        ],
                      ),
                    ),
                    if (failed) ...[
                      const SizedBox(height: 14),
                      Text(
                        _order.failureReason ?? 'Terjadi kesalahan',
                        style: type(14, weight: 600, color: Palette.coral),
                      ),
                      const SizedBox(height: 14),
                      PrimaryButton(
                        label: 'Kembali',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(int index, bool failed) {
    final stage = _stages[index];
    final current = _stage;
    final done = index < current;
    final active = index == current && !failed;
    final broken = index == current && failed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AnimatedOpacity(
        opacity: done || active || broken ? 1 : 0.36,
        duration: const Duration(milliseconds: 320),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
                child: done
                    ? Container(
                        key: const ValueKey('done'),
                        decoration: const BoxDecoration(
                          color: Palette.mint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Palette.ink,
                        ),
                      )
                    : broken
                    ? Container(
                        key: const ValueKey('broken'),
                        decoration: const BoxDecoration(
                          color: Palette.coral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Palette.ink,
                        ),
                      )
                    : active
                    ? RotationTransition(
                        key: const ValueKey('active'),
                        turns: _spin,
                        child: const CircularProgressIndicator(
                          value: 0.28,
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          color: Palette.text,
                          backgroundColor: Palette.surfaceHigh,
                        ),
                      )
                    : Container(
                        key: const ValueKey('idle'),
                        decoration: const BoxDecoration(
                          color: Palette.surfaceHigh,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stage.label, style: type(15, weight: 680)),
                  const SizedBox(height: 1),
                  Text(stage.detail, style: type(12.5, color: Palette.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
