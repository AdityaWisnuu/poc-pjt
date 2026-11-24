import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/aurora.dart';
import '../widgets/common.dart';
import 'remit_form.dart';

const railLabels = {
  'crypto': 'Kripto end-to-end',
  'b2b': 'USDC antar lembaga, pengguna pakai uang lokal',
  'fiat': 'Tanpa kripto, jalur fiat',
};

class RemitStartScreen extends StatefulWidget {
  const RemitStartScreen({super.key});

  @override
  State<RemitStartScreen> createState() => _RemitStartScreenState();
}

class _RemitStartScreenState extends State<RemitStartScreen> {
  RemitCatalog? _catalog;
  String? _error;
  String _direction = 'INBOUND';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = await Api.instance.remitCatalog();
      if (mounted) setState(() => _catalog = catalog);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final catalog = _catalog;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height * 0.42,
            child: const Aurora(energy: 0.15),
          ),
          SafeArea(
            bottom: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (catalog?.isSimulation ?? false)
                      Text(
                        'Mode simulasi',
                        style: type(
                          12.5,
                          weight: 600,
                          color: const Color(0xCCFFFFFF),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 26),
                Text('Kirim uang', style: type(34, weight: 750)),
                const SizedBox(height: 6),
                Text(
                  'Jalurnya mengikuti sikap tiap negara terhadap kripto.',
                  style: type(
                    14.5,
                    weight: 550,
                    color: const Color(0xD9FFFFFF),
                  ),
                ),
                const SizedBox(height: 22),
                _DirectionToggle(
                  value: _direction,
                  onChanged: (value) => setState(() => _direction = value),
                ),
                const SizedBox(height: 18),
                if (_error != null)
                  Pressable(
                    onTap: () {
                      setState(() => _error = null);
                      _load();
                    },
                    child: Text(
                      '$_error · coba lagi',
                      style: type(14, weight: 600, color: Palette.coral),
                    ),
                  ),
                if (catalog != null)
                  Reveal(
                    delay: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Palette.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Palette.line),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          for (final corridor
                              in [...catalog.corridors]..sort(
                                (a, b) => b.volume2025.compareTo(a.volume2025),
                              ))
                            _CorridorRow(
                              corridor: corridor,
                              onTap: () => Navigator.of(context).push(
                                fadeRoute(
                                  RemitFormScreen(
                                    catalog: catalog,
                                    corridor: corridor,
                                    direction: _direction,
                                  ),
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
        ],
      ),
    );
  }
}

class _DirectionToggle extends StatelessWidget {
  const _DirectionToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Palette.ink.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Palette.line),
    ),
    child: Row(
      children: [
        for (final (key, label) in const [
          ('INBOUND', 'Masuk ke Indonesia'),
          ('OUTBOUND', 'Keluar dari Indonesia'),
        ])
          Expanded(
            child: Pressable(
              onTap: () => onChanged(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == key ? Palette.text : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  label,
                  style: type(
                    13.5,
                    weight: 700,
                    color: value == key ? Palette.ink : Palette.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Short label for how money moves, coloured by the country's type.
const railShort = {
  'crypto': 'Kripto',
  'b2b': 'Lewat lembaga',
  'fiat': 'Tanpa kripto',
};

const typeColors = {
  'A': Palette.mint,
  'B': Color(0xFF8FA8FF),
  'C': Color(0xFFFFC857),
  'D': Palette.coral,
};

/// Round country flag (circle-flags SVG, MIT), clipped so it stays round.
class Flag extends StatelessWidget {
  const Flag(this.code, {super.key, this.size = 40});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: ClipOval(
      child: SvgPicture.asset(
        'assets/flags/${code.toLowerCase()}.svg',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    ),
  );
}

class _CorridorRow extends StatelessWidget {
  const _CorridorRow({required this.corridor, required this.onTap});

  final Corridor corridor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = typeColors[corridor.type] ?? Palette.muted;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Flag(corridor.code),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(corridor.country, style: type(16, weight: 650)),
                  const SizedBox(height: 1),
                  Text(
                    corridor.currency,
                    style: type(12.5, color: Palette.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                railShort[corridor.rail] ?? corridor.rail,
                style: type(12, weight: 700, color: color),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Palette.faint),
          ],
        ),
      ),
    );
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge(this.kind, {super.key});

  final String kind;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: (typeColors[kind] ?? Palette.muted).withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      kind,
      style: type(14, weight: 800, color: typeColors[kind] ?? Palette.muted),
    ),
  );
}
