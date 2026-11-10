import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/ooredoo_api.dart';
import '../core/ooredoo_parser.dart';
import '../core/recent_numbers.dart';
import '../core/text_utils.dart';
import '../core/ussd_controller.dart';

class FlowScreen extends StatelessWidget {
  const FlowScreen({super.key, required this.title, required this.serviceCode});

  final String title;
  final String serviceCode;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          UssdController(api: ctx.read<OoredooApi>(), serviceCode: serviceCode)..start(),
      child: _FlowView(title: title),
    );
  }
}

class _FlowView extends StatelessWidget {
  const _FlowView({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UssdController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (c.active)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${c.timeLeft}s',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: c.timeLeft <= 10 ? scheme.error : null,
                    )),
              ),
            ),
        ],
      ),
      body: SafeArea(child: _body(context, c)),
    );
  }

  Widget _body(BuildContext context, UssdController c) {
    if (c.finished) {
      return (c.error == null && c.receipt != null) ? _ReceiptView(c) : _ErrorView(c);
    }
    if (c.current == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _StepView(controller: c);
  }
}

// ── One step of the flow ─────────────────────────────────────

class _StepView extends StatelessWidget {
  const _StepView({required this.controller});
  final UssdController controller;

  @override
  Widget build(BuildContext context) {
    final r = controller.current!;
    final menu = r.options.where((o) => !o.isNav).toList();
    final nav = r.options.where((o) => o.isNav).toList();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (controller.loading) const LinearProgressIndicator(),
        Card(
          color: scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(r.mainText, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
        const SizedBox(height: 16),
        if (menu.isNotEmpty)
          ...menu.map((o) => Card(
                child: ListTile(
                  leading: Text(o.id,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18, color: scheme.primary)),
                  title: Text(o.label),
                  enabled: !controller.loading,
                  onTap: () => controller.choose(o),
                ),
              ))
        else if (r.options.isEmpty)
          _InputArea(
            key: ValueKey(controller.step),
            controller: controller,
            response: r,
          ),
        if (nav.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: nav
                  .map((o) => TextButton(
                        onPressed: controller.loading ? null : () => controller.choose(o),
                        child: Text(o.label),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _InputArea extends StatefulWidget {
  const _InputArea({super.key, required this.controller, required this.response});
  final UssdController controller;
  final UssdResponse response;

  @override
  State<_InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<_InputArea> {
  final _text = TextEditingController();
  List<String> _recent = [];

  PromptType? get _type => widget.response.promptType;

  @override
  void initState() {
    super.initState();
    if (_type == PromptType.customerNumber) {
      RecentNumbers.load().then((l) {
        if (mounted) setState(() => _recent = l);
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canSend {
    final v = _text.text.trim();
    if (v.isEmpty) return false;
    if (_type == PromptType.customerNumber) return v.length >= 9;
    return true;
  }

  void _send() {
    if (_canSend && !widget.controller.loading) widget.controller.submit(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final r = widget.response;

    if (_type == PromptType.confirm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.transferAmount != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${formatDa(r.transferAmount)}  →  ${r.transferTarget ?? ''}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          FilledButton(
            onPressed: c.loading ? null : () => c.submit('1'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Confirm'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    final isPin = _type == PromptType.pin;
    final isAmount = _type == PromptType.amount;
    final isPhone = _type == PromptType.customerNumber;
    final label = isPin
        ? 'PIN code'
        : isAmount
            ? 'Amount'
            : isPhone
                ? 'Customer number'
                : 'Your answer';

    final suggestions = isPhone
        ? _recent.where((n) => n.startsWith(_text.text) && n != _text.text).toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPin && r.debitAmount != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('You will be charged ${formatDa(r.debitAmount)}',
                style: Theme.of(context).textTheme.titleMedium),
          ),
        TextField(
          controller: _text,
          autofocus: true,
          obscureText: isPin,
          enableSuggestions: !isPin,
          autocorrect: !isPin,
          keyboardType: isPhone
              ? TextInputType.phone
              : (isPin || isAmount)
                  ? TextInputType.number
                  : TextInputType.text,
          inputFormatters:
              (isPhone || isPin || isAmount) ? [FilteringTextInputFormatter.digitsOnly] : null,
          maxLength: isPhone ? 10 : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixText: isAmount ? 'DA' : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _send(),
        ),
        if (suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              children: suggestions
                  .map((n) => ActionChip(
                        label: Text(n),
                        onPressed: () => setState(() {
                          _text.text = n;
                          _text.selection = TextSelection.collapsed(offset: n.length);
                        }),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 4),
        FilledButton(
          onPressed: (_canSend && !c.loading) ? _send : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Send'),
        ),
      ],
    );
  }
}

// ── Final screens ────────────────────────────────────────────

class _ReceiptView extends StatelessWidget {
  const _ReceiptView(this.c);
  final UssdController c;

  @override
  Widget build(BuildContext context) {
    final r = c.receipt!;
    final scheme = Theme.of(context).colorScheme;

    Widget row(String k, String? v) => v == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 72),
        const SizedBox(height: 8),
        Text('Done',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              row('Number', r.number),
              row('Amount', r.amount == null ? null : formatDa(r.amount)),
              row('Offer', r.offerLabel),
              row('Operation', r.operationId),
              if (r.loanPaid) row('Loan repaid', formatDa(r.loanAmount)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: const Text('Ooredoo message'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(r.text, style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            c.reset();
            c.start();
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('New operation'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView(this.c);
  final UssdController c;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(Icons.error_outline, color: scheme.error, size: 72),
        const SizedBox(height: 16),
        Card(
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(c.error ?? 'The operation did not complete.',
                style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            c.reset();
            c.start();
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Try again'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
