import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'remit_confirm.dart';
import 'remit_start.dart';

/// What the sender fills in. Kept so an expired quote can be priced again.
class RemitRequest {
  const RemitRequest({
    required this.direction,
    required this.corridor,
    required this.fundingCurrency,
    required this.amount,
    required this.senderName,
    required this.bank,
    required this.account,
  });

  final String direction;
  final Corridor corridor;
  final String fundingCurrency;
  final num amount;
  final String senderName;
  final String bank;
  final String account;

  Future<RemitQuote> price() => Api.instance.remitQuote(
    direction: direction,
    corridor: corridor.code,
    fundingCurrency: fundingCurrency,
    amount: amount,
    senderName: senderName,
    bank: bank,
    account: account,
  );
}

class RemitFormScreen extends StatefulWidget {
  const RemitFormScreen({
    super.key,
    required this.catalog,
    required this.corridor,
    required this.direction,
  });

  final RemitCatalog catalog;
  final Corridor corridor;
  final String direction;

  @override
  State<RemitFormScreen> createState() => _RemitFormScreenState();
}

class _RemitFormScreenState extends State<RemitFormScreen> {
  final _amount = TextEditingController();
  final _sender = TextEditingController();
  final _account = TextEditingController();
  late final List<String> _fundings =
      widget.corridor.funding[widget.direction] ?? const [];
  late String _funding = _fundings.first;
  late String _bank = _banks.first.code;
  bool _busy = false;
  String? _error;

  bool get _inbound => widget.direction == 'INBOUND';
  List<RemitBank> get _banks =>
      _inbound ? widget.catalog.idBanks : widget.corridor.banks;
  List<RemitSample> get _samples =>
      _inbound ? widget.catalog.idSamples : widget.corridor.samples;

  @override
  void dispose() {
    _amount.dispose();
    _sender.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Rupiah is whole; other currencies accept a comma or a dot as decimal.
    final raw = _amount.text.trim();
    final amount = _funding == 'IDR'
        ? num.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''))
        : num.tryParse(raw.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Isi nominal');
      return;
    }
    if (_sender.text.trim().length < 2) {
      setState(() => _error = 'Isi nama pengirim');
      return;
    }
    if (_account.text.trim().length < 6) {
      setState(() => _error = 'Isi nomor rekening penerima');
      return;
    }
    final request = RemitRequest(
      direction: widget.direction,
      corridor: widget.corridor,
      fundingCurrency: _funding,
      amount: amount,
      senderName: _sender.text.trim(),
      bank: _bank,
      account: _account.text.trim(),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final quote = await request.price();
      if (!mounted) return;
      await Navigator.of(context).push(
        fadeRoute(
          RemitConfirmScreen(
            request: request,
            quote: quote,
            isLive: !widget.catalog.isSimulation,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.corridor;
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    background: Palette.surface,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  TypeBadge(c.type),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Flag(_inbound ? c.code : 'ID', size: 34),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Palette.muted,
                    ),
                  ),
                  Flag(_inbound ? 'ID' : c.code, size: 34),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _inbound
                    ? '${c.country} → Indonesia'
                    : 'Indonesia → ${c.country}',
                style: type(27, weight: 750),
              ),
              const SizedBox(height: 10),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      railLabels[c.rail] ?? c.rail,
                      style: type(14, weight: 700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${c.typeLabel}. ${c.reason}.',
                      style: type(12.5, color: Palette.muted, height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mitra di ${c.country}: ${c.partner}',
                      style: type(12.5, color: Palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _Label(_inbound ? 'Pengirim membayar' : 'Kamu membayar'),
              if (_fundings.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final f in _fundings)
                        _Chip(
                          label: f,
                          selected: f == _funding,
                          onTap: () => setState(() => _funding = f),
                        ),
                    ],
                  ),
                ),
              _Field(
                controller: _amount,
                hint: _funding == 'IDR' ? 'Contoh 50000' : 'Contoh 2',
                suffix: _funding,
                big: true,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              _Label('Nama pengirim'),
              _Field(controller: _sender, hint: 'Sesuai identitas'),
              const SizedBox(height: 16),
              _Label(
                'Rekening penerima di ${_inbound ? 'Indonesia' : c.country}',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in _banks)
                    _Chip(
                      label: b.name,
                      selected: b.code == _bank,
                      onTap: () => setState(() => _bank = b.code),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _Field(
                controller: _account,
                hint: 'Nomor rekening',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 10),
              Text(
                'Rekening contoh',
                style: type(12.5, weight: 650, color: Palette.faint),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _samples)
                    _Chip(
                      label: s.name,
                      selected: false,
                      onTap: () => setState(() {
                        _bank = s.bank;
                        _account.text = s.account;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 22,
                child: _error == null
                    ? null
                    : Text(
                        _error!,
                        style: type(13.5, weight: 600, color: Palette.coral),
                      ),
              ),
              const SizedBox(height: 6),
              PrimaryButton(
                label: _busy ? 'Mengecek…' : 'Cek rekening & kurs',
                onTap: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Palette.line),
    ),
    child: child,
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: type(13, weight: 650, color: Palette.muted)),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? Palette.text : Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? Palette.text : Palette.line),
      ),
      child: Text(
        label,
        style: type(
          13,
          weight: 650,
          color: selected ? Palette.ink : Palette.text,
        ),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.suffix,
    this.big = false,
    this.keyboard = TextInputType.text,
  });

  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final bool big;
  final TextInputType keyboard;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Palette.line),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboard,
            textCapitalization: TextCapitalization.words,
            inputFormatters: keyboard == TextInputType.number
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            cursorColor: Palette.mint,
            style: type(big ? 26 : 16, weight: big ? 700 : 600, tabular: true),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: type(
                big ? 26 : 16,
                weight: big ? 700 : 500,
                color: Palette.faint,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: big ? 16 : 15),
            ),
          ),
        ),
        if (suffix != null)
          Text(suffix!, style: type(15, weight: 700, color: Palette.muted)),
      ],
    ),
  );
}
