import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../core/auth_store.dart';
import 'flow_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, String title, String code) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FlowScreen(title: title, serviceCode: code),
    ));
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Signed in as ${auth.phone ?? ''}',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          _ServiceCard(
            icon: Icons.bolt,
            title: 'Storm',
            subtitle: 'Top up a number',
            onTap: () => _open(context, 'Storm', OoredooConfig.stormCode),
          ),
          const SizedBox(height: 12),
          _ServiceCard(
            icon: Icons.inventory_2_outlined,
            title: 'Bundle',
            subtitle: 'Buy an internet / call bundle',
            onTap: () => _open(context, 'Bundle', OoredooConfig.bundleCode),
          ),
        ],
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
