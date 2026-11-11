import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../core/auth_store.dart';
import '../core/ooredoo_parser.dart';
import '../core/pool_store.dart';
import '../core/text_utils.dart';
import 'flow_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PoolStore>().refresh();
    });
  }

  Future<void> _open(String title, String code, String kind) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FlowScreen(title: title, serviceCode: code, kind: kind),
    ));
    // balances changed after a purchase; wait for the flow screen to be disposed first
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) context.read<PoolStore>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ooredoo'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<PoolStore>().refresh(manual: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Signed in as ${auth.phone ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            const _PoolCard(),
            const SizedBox(height: 16),
            _ServiceCard(
              icon: Icons.bolt,
              title: 'Storm',
              subtitle: 'Top up a number',
              onTap: () => _open('Storm', OoredooConfig.stormCode, 'storm'),
            ),
            const SizedBox(height: 12),
            _ServiceCard(
              icon: Icons.inventory_2_outlined,
              title: 'Bundle',
              subtitle: 'Buy an internet / call bundle',
              onTap: () => _open('Bundle', OoredooConfig.bundleCode, 'bundle'),
            ),
            const SizedBox(height: 12),
            _ServiceCard(
              icon: Icons.history,
              title: 'History',
              subtitle: 'Every number you topped up or bought a bundle for',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ooredoo pool ─────────────────────────────────────────────

class _PoolCard extends StatelessWidget {
  const _PoolCard();

  @override
  Widget build(BuildContext context) {
    final pool = context.watch<PoolStore>();
    final b = pool.balance;
    final scheme = Theme.of(context).colorScheme;

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k),
              Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Ooredoo pool',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (pool.loading)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                else
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => pool.refresh(manual: true),
                  ),
              ],
            ),
            if (b == null && pool.error == null && pool.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Reading balances from Ooredoo…'),
              ),
            if (b != null) ...[
              Text(formatDa(b.storm),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Text('Storm account'),
              const Divider(height: 24),
              row('Loyalty points', formatDa(b.loyalty)),
              row('Bonus', '${formatDa(b.bonus)}${b.bonusExpiry != null ? '  (until ${b.bonusExpiry})' : ''}'),
              row('Recharge card account', formatDa(b.rechargeCard)),
              const SizedBox(height: 8),
              Text('Updated ${formatDateTime(b.fetchedAt)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (pool.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(pool.error!, style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, size: 30, color: scheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
