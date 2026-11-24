import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/aurora.dart';
import '../widgets/common.dart';

class RemitProgressScreen extends StatefulWidget {
  const RemitProgressScreen({super.key, required this.remittance});

  final Remittance remittance;

  @override
  State<RemitProgressScreen> createState() => _RemitProgressScreenState();
}

class _RemitProgressScreenState extends State<RemitProgressScreen>
    with SingleTickerProviderStateMixin {
  late Remittance _item = widget.remittance;
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..repeat();
  Timer? _poll;
  int _last = 0;

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

  /// Index of the step in progress; steps.length once finished.
  int _stageOf(Remittance item) {
    if (item.isSuccess) return item.steps.length;
    final index = item.steps.indexWhere((s) => s.status == item.status);
    return index < 0 ? _last : index;
  }

  Future<void> _fetch() async {
    try {
      final item = await Api.instance.remittance(_item.id);
      if (!mounted) return;
      final next = _stageOf(item);
      if (next > _last) {
        _last = next;
        HapticFeedback.lightImpact();
      }
      setState(() => _item = item);
      if (item.isSuccess || item.isFailed) {
        _poll?.cancel();
        HapticFeedback.heavyImpact();
      }
    } on ApiException {
      // A dropped poll is not a failed transfer. Keep polling.
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final done = item.isSuccess;
    final failed = item.isFailed;
    return PopScope(
      canPop: done || failed,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Aurora(
              energy: failed ? 0 : (done ? 0.6 : 1),
              success: done ? 1 : 0,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      done
                          ? 'Uang sampai di rekening'
                          : failed
                          ? (item.status == 'NEEDS_REVIEW'
                                ? 'Perlu dicek'
                                : 'Transfer gagal')
                          : 'Mengirim',
                      style: type(
                        16,
                        weight: 650,
                        color: done ? Palette.ink : Palette.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      child: Text(
                        money(item.receiveAmount, item.receiveCurrency),
                        style: type(
                          46,
                          weight: 750,
                          tabular: true,
                          color: done ? Palette.ink : Palette.text,
                        ),
                      ),
                    ),
                    Text(
                      'ke ${item.recipient.name} · ${item.recipient.country}',
                      style: type(
                        15,
                        weight: 600,
                        color: done ? Palette.ink : const Color(0xD9FFFFFF),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                      decoration: BoxDecoration(
                        color: Palette.ink.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Palette.line),
                      ),
                      child: done
                          ? _receipt(item)
                          : Column(
                              children: [
                                for (var i = 0; i < item.steps.length; i++)
                                  _row(item, i, failed),
                              ],
                            ),
                    ),
                    if (failed) ...[
                      const SizedBox(height: 14),
                      Text(
                        item.failureReason ?? 'Terjadi kesalahan',
                        style: type(14, weight: 600, color: Palette.coral),
                      ),
                    ],
                    if (done || failed) ...[
                      const SizedBox(height: 14),
                      Pressable(
                        onTap: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                        child: Container(
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: done ? Palette.ink : Palette.text,
                            borderRadius: BorderRadius.circular(29),
                          ),
                          child: Text(
                            'Selesai',
                            style: type(
                              16,
                              weight: 700,
                              color: done ? Palette.text : Palette.ink,
                            ),
                          ),
                        ),
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

  Widget _receipt(Remittance item) => Column(
    children: [
      _line('Dikirim', money(item.sendAmount, item.fundingCurrency)),
      _line('Pengirim', item.sender.name),
      _line('Rekening', '${item.recipient.bankName} ${item.recipient.account}'),
      if (item.txId != null && item.txId!.isNotEmpty)
        _line('TxID USDC', item.txId!),
      if (item.payoutReference != null)
        _line('Ref. transfer', item.payoutReference!),
      _line('Waktu', wibTime(item.completedAt ?? item.createdAt)),
      if (item.completedAt != null)
        _line(
          'Durasi',
          '${(item.completedAt!.difference(item.createdAt).inMilliseconds / 1000).toStringAsFixed(1).replaceAll('.', ',')} detik',
        ),
    ],
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
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

  Widget _row(Remittance item, int index, bool failed) {
    final step = item.steps[index];
    final current = _stageOf(item);
    final done = index < current;
    final active = index == current && !failed;
    final broken = index == current && failed;
    final live = step.real && item.mode == 'LIVE';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AnimatedOpacity(
        opacity: done || active || broken ? 1 : 0.36,
        duration: const Duration(milliseconds: 320),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: done
                  ? Container(
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
                      decoration: const BoxDecoration(
                        color: Palette.surfaceHigh,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label, style: type(15, weight: 680)),
                  Text(step.detail, style: type(12.5, color: Palette.muted)),
                ],
              ),
            ),
            if (live)
              Text('Asli', style: type(11.5, weight: 750, color: Palette.mint)),
          ],
        ),
      ),
    );
  }
}
