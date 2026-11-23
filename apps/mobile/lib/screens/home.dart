import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/aurora.dart';
import '../widgets/common.dart';
import 'scan.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  Wallet? _wallet;
  List<Order> _orders = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.instance.wallet(),
        Api.instance.orders(),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = results[0] as Wallet;
        _orders = results[1] as List<Order>;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _openScanner() async {
    await Navigator.of(
      context,
    ).push(fadeRoute(ScanScreen(isSimulation: _wallet?.isSimulation ?? false)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final wallet = _wallet;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height * 0.66,
            child: const Aurora(),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _load,
              color: Palette.ink,
              backgroundColor: Palette.text,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                children: [
                  _header(wallet),
                  SizedBox(height: height * 0.075),
                  _balance(wallet),
                  SizedBox(height: height * 0.05),
                  _scanButton(),
                  SizedBox(height: height * 0.055),
                  if (_error != null) _errorCard(),
                  if (wallet != null) ...[
                    Reveal(delay: 120, child: _assets(wallet)),
                    const SizedBox(height: 12),
                    Reveal(delay: 220, child: _activity()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(Wallet? wallet) => SizedBox(
    height: 44,
    child: Row(
      children: [
        Text('pjt', style: type(25, weight: 800, spacing: -1.2)),
        const Spacer(),
        if (wallet?.isSimulation ?? false)
          Text(
            'Mode simulasi',
            style: type(12.5, weight: 600, color: const Color(0xCCFFFFFF)),
          ),
      ],
    ),
  );

  Widget _balance(Wallet? wallet) => Column(
    children: [
      Text(
        'Total saldo',
        style: type(14, weight: 600, color: const Color(0xD9FFFFFF)),
      ),
      const SizedBox(height: 8),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: wallet == null
            ? Text('Rp—', style: type(50, weight: 700))
            : CountUp(
                value: wallet.totalIdr,
                format: rupiah,
                style: type(50, weight: 700, tabular: true),
              ),
      ),
    ],
  );

  Widget _scanButton() => Center(
    child: Column(
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) {
                  final t = Curves.easeOut.transform(_pulse.value);
                  return Container(
                    width: 84 + 48 * t,
                    height: 84 + 48 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.42 * (1 - t)),
                        width: 1.4,
                      ),
                    ),
                  );
                },
              ),
              Pressable(
                onTap: _error != null && _wallet == null ? _load : _openScanner,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: Palette.text,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 34,
                    color: Palette.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        Text('Scan QRIS', style: type(14.5, weight: 700)),
      ],
    ),
  );

  Widget _errorCard() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Pressable(
      onTap: _load,
      child: _Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Palette.coral,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_error!, style: type(14.5, weight: 600))),
              Text(
                'Coba lagi',
                style: type(13.5, weight: 700, color: Palette.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _assets(Wallet wallet) => _Card(
    child: Column(
      children: [
        for (final asset in wallet.assets)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                TokenIcon(asset.symbol, size: 42),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.symbol, style: type(15.5, weight: 700)),
                      const SizedBox(height: 2),
                      Text(asset.name, style: type(12.5, color: Palette.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rupiah(asset.idrValue),
                      style: type(15.5, weight: 700, tabular: true),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${asset.symbol == 'USDC' ? usdc(asset.amount) : plainNumber(num.parse(asset.amount))} ${asset.symbol}',
                      style: type(12.5, color: Palette.muted, tabular: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _activity() => _Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              'Aktivitas',
              style: type(13.5, weight: 650, color: Palette.muted),
            ),
          ),
          if (_orders.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Text(
                'Pembayaran pertamamu akan muncul di sini.',
                style: type(14, color: Palette.faint),
              ),
            ),
          for (final order in _orders.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Palette.surfaceHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      order.merchantName.characters.first.toUpperCase(),
                      style: type(16, weight: 750),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.merchantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type(15, weight: 650),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.isFailed ? 'Gagal' : shortTime(order.createdAt),
                          style: type(
                            12.5,
                            color: order.isFailed
                                ? Palette.coral
                                : Palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '-${rupiah(order.amountIdr)}',
                        style: type(15, weight: 700, tabular: true),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${usdc(order.usdcAmount)} USDC',
                        style: type(12.5, color: Palette.muted, tabular: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Palette.line),
    ),
    child: child,
  );
}
