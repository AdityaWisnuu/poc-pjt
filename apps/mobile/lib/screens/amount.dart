import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'confirm.dart';

/// Static QRIS has no amount, so the payer enters it.
class AmountScreen extends StatefulWidget {
  const AmountScreen({super.key, required this.quote});

  final Quote quote;

  @override
  State<AmountScreen> createState() => _AmountScreenState();
}

class _AmountScreenState extends State<AmountScreen> {
  String _digits = '';
  bool _busy = false;
  String? _error;

  int get _amount => int.tryParse(_digits) ?? 0;
  int get _min => widget.quote.minIdr ?? 11000;
  int get _max => widget.quote.maxIdr ?? 100000;
  bool get _valid => _amount >= _min && _amount <= _max;

  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (key == 'del') {
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
      } else if (_digits.length < 7 &&
          !(_digits.isEmpty && key.startsWith('0'))) {
        _digits = (_digits + key).substring(
          0,
          (_digits.length + key.length).clamp(0, 7),
        );
      }
    });
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      final quote = await Api.instance.quote(
        widget.quote.qr,
        amountIdr: _amount,
      );
      if (!mounted) return;
      await Navigator.of(
        context,
      ).pushReplacement(fadeRoute(ConfirmScreen(quote: quote)));
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint =
        _error ??
        (_amount > _max
            ? 'Maksimal ${rupiah(_max)}'
            : 'Minimal ${rupiah(_min)}');
    final hintIsError = _error != null || _amount > _max;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: RoundIconButton(
                  icon: Icons.close_rounded,
                  background: Palette.surfaceHigh,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const Spacer(),
              Text(
                widget.quote.merchantName,
                textAlign: TextAlign.center,
                style: type(17, weight: 700),
              ),
              const SizedBox(height: 14),
              FittedBox(
                child: Text(
                  rupiah(_amount),
                  style: type(
                    54,
                    weight: 700,
                    tabular: true,
                    color: _digits.isEmpty ? Palette.faint : Palette.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                style: type(
                  13.5,
                  weight: 600,
                  color: hintIsError ? Palette.coral : Palette.muted,
                ),
              ),
              const Spacer(),
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['000', '0', 'del'],
              ])
                Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        child: Pressable(
                          onTap: () => _press(key),
                          child: SizedBox(
                            height: 66,
                            child: Center(
                              child: key == 'del'
                                  ? const Icon(
                                      Icons.backspace_outlined,
                                      size: 26,
                                    )
                                  : Text(key, style: type(25, weight: 600)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: _busy ? 'Menghitung…' : 'Lanjut',
                onTap: _valid && !_busy ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
