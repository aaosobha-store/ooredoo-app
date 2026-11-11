import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/history_store.dart';
import '../core/text_utils.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';
  String _type = 'all'; // all | storm | bundle
  bool _byNumber = false;

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok == true;
  }

  void _details(HistoryEntry e) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.number, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _kv('Type', e.type == 'storm' ? 'Storm' : 'Bundle'),
            _kv('Date', formatDateTime(e.at)),
            _kv('Amount', e.amount == null ? null : formatDa(e.amount)),
            _kv('Offer', e.offer),
            _kv('Operation', e.operationId),
            if (e.loanPaid) _kv('Loan repaid', formatDa(e.loanAmount)),
            if (e.forSelf) _kv('Note', 'Bought for your own number'),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String? v) => v == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k),
              Flexible(
                  child: Text(v,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        );

  Widget _tile(HistoryEntry e, {bool showNumber = true}) {
    final store = context.read<HistoryStore>();
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(e.type == 'storm' ? Icons.bolt : Icons.inventory_2_outlined,
            color: scheme.primary),
      ),
      title: Text(showNumber ? e.number : (e.offer ?? (e.type == 'storm' ? 'Storm' : 'Bundle'))),
      subtitle: Text(
          '${showNumber ? '${e.offer ?? (e.type == 'storm' ? 'Storm' : 'Bundle')} • ' : ''}${formatDateTime(e.at)}'),
      trailing: Text(e.amount == null ? '' : formatDa(e.amount),
          style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () => _details(e),
      onLongPress: () async {
        if (await _confirm('Delete this entry?', '${e.number} • ${formatDateTime(e.at)}')) {
          store.remove(e.id);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HistoryStore>();
    final list = store.entries
        .where((e) => (_type == 'all' || e.type == _type) && e.number.contains(_query))
        .toList();
    final total = list.fold<double>(0, (s, e) => s + (e.amount ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (store.entries.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                if (await _confirm('Clear all history?', 'This cannot be undone.')) {
                  store.clear();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Search a number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in const [
                      ['all', 'All'],
                      ['storm', 'Storm'],
                      ['bundle', 'Bundle'],
                    ])
                      ChoiceChip(
                        label: Text(t[1]),
                        selected: _type == t[0],
                        onSelected: (_) => setState(() => _type = t[0]),
                      ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: _byNumber ? 'Show by date' : 'Group by number',
                  icon: Icon(_byNumber ? Icons.view_list : Icons.people_outline),
                  onPressed: () => setState(() => _byNumber = !_byNumber),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${list.length} operation${list.length == 1 ? '' : 's'}'),
                Text('Total ${formatDa(total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Nothing here yet.'))
                : (_byNumber ? _grouped(list) : _flat(list)),
          ),
        ],
      ),
    );
  }

  Widget _flat(List<HistoryEntry> list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => _tile(list[i]),
      );

  Widget _grouped(List<HistoryEntry> list) {
    final groups = <String, List<HistoryEntry>>{};
    for (final e in list) {
      groups.putIfAbsent(e.number, () => []).add(e);
    }
    final numbers = groups.keys.toList()
      ..sort((a, b) => groups[b]!.first.at.compareTo(groups[a]!.first.at));

    return ListView.builder(
      itemCount: numbers.length,
      itemBuilder: (_, i) {
        final n = numbers[i];
        final items = groups[n]!;
        final sum = items.fold<double>(0, (s, e) => s + (e.amount ?? 0));
        return ExpansionTile(
          title: Text(n, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${items.length} operation${items.length == 1 ? '' : 's'} • ${formatDa(sum)} • last ${formatDateTime(items.first.at)}'),
          children: items.map((e) => _tile(e, showNumber: false)).toList(),
        );
      },
    );
  }
}
