import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/aurora.dart';
import '../widgets/common.dart';
import '../widgets/slide_to_pay.dart';
import 'remit_form.dart';
import 'remit_progress.dart';

class RemitConfirmScreen extends StatefulWidget {
  const RemitConfirmScreen({
    super.key,
    required this.request,
    required this.quote,
    required this.isLive,
  });

  final RemitRequest request;
  final RemitQuote quote;
  final bool isLive;

  @override
  State<RemitConfirmScreen> createState() => _RemitConfirmScreenState();
}

class _RemitConfirmScreenState extends State<RemitConfirmScreen> {
  late RemitQuote _quote = widget.quote;
  Timer? _timer;
  double _remaining = 0;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void _tick() {
    final left =
        _quote.expiresAt.difference(DateTime.now()).inMilliseconds / 1000;
    if (!mounted) return;
    setState(() => _remaining = left.clamp(0, _quote.ttlSeconds.toDouble()));
    if (left <= 0) _timer?.cancel();
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final quote = await widget.request.price();
      if (!mounted) return;
      setState(() => _quote = quote);
      _start();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _send() async {
    try {
      final item = await Api.instance.remitSend(_quote.quoteId);
      _timer?.cancel();
      if (!mounted) return;
      await Navigator.of(
        context,
      ).pushReplacement(fadeRoute(RemitProgressScreen(remittance: item)));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final q = _quote;
    final expired = _remaining <= 0;
    final message = _error ?? q.blocked;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height * 0.5,
            child: const Aurora(energy: 0.25),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0x33000000),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          expired
                              ? 'Kurs habis'
                              : 'Kurs dikunci ${_remaining.ceil()}d',
                          style: type(
                            13.5,
                            weight: 700,
                            tabular: true,
                            color: _remaining <= 10
                                ? Palette.coral
                                : Palette.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    children: [
                      Reveal(child: _recipient(q)),
                      const SizedBox(height: 16),
                      Reveal(
                        delay: 60,
                        child: FittedBox(
                          child: Text(
                            money(q.receiveAmount, q.receiveCurrency),
                            style: type(48, weight: 750, tabular: true),
                          ),
                        ),
                      ),
                      Reveal(
                        delay: 80,
                        child: Text(
                          'diterima · dari ${money(q.sendAmount, q.fundingCurrency)}',
                          textAlign: TextAlign.center,
                          style: type(
                            14,
                            weight: 600,
                            color: const Color(0xD9FFFFFF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Reveal(delay: 120, child: _pricing(q)),
                      const SizedBox(height: 12),
                      Reveal(delay: 160, child: _route(q)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    children: [
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
                      expired
                          ? PrimaryButton(
                              label: _refreshing
                                  ? 'Memperbarui…'
                                  : 'Perbarui kurs',
                              onTap: _refreshing ? null : _refresh,
                            )
                          : SlideToPay(
                              label: 'Geser untuk kirim',
                              enabled: q.blocked == null && !_refreshing,
                              onComplete: _send,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recipient(RemitQuote q) => Column(
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
          q.recipient.name.characters.first,
          style: type(23, weight: 800, color: Palette.ink),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        q.recipient.name,
        textAlign: TextAlign.center,
        style: type(19, weight: 700),
      ),
      const SizedBox(height: 3),
      Text(
        '${q.recipient.bankName} ${q.recipient.account} · ${q.recipient.country}',
        style: type(13.5, weight: 550, color: const Color(0xCCFFFFFF)),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Palette.mint.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Nama rekening terverifikasi',
          style: type(12, weight: 700, color: Palette.mint),
        ),
      ),
    ],
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: Palette.ink.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Palette.line),
    ),
    child: child,
  );

  Widget _pricing(RemitQuote q) => _card(
    Column(
      children: [
        _line('Kurs efektif', q.rate, strong: true),
        for (final line in q.lines) _line(line.label, line.value),
        if (q.assumptions.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final a in q.assumptions)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('· $a', style: type(11.5, color: Palette.faint)),
              ),
            ),
        ],
      ],
    ),
  );

  Widget _route(RemitQuote q) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Jalur', style: type(13, weight: 650, color: Palette.muted)),
        const SizedBox(height: 8),
        for (final step in q.steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.label, style: type(14, weight: 650)),
                      Text(step.detail, style: type(12, color: Palette.muted)),
                    ],
                  ),
                ),
                _Tag(real: step.real && widget.isLive),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _line(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: type(13, color: Palette.muted)),
        ),
        Text(
          value,
          style: type(13.5, weight: strong ? 750 : 600, tabular: true),
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.real});

  final bool real;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: (real ? Palette.mint : Palette.muted).withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      real ? 'Asli' : 'Simulasi',
      style: type(
        11.5,
        weight: 700,
        color: real ? Palette.mint : Palette.muted,
      ),
    ),
  );
}
