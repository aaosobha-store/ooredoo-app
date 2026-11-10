import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;
  final _password = TextEditingController();
  bool _hide = true;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: context.read<AuthStore>().savedPhone ?? '');
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await context
        .read<AuthStore>()
        .login(_phone.text, _password.text, remember: _remember);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Ooredoo',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: scheme.primary, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Storm & Bundle',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Ooredoo phone number',
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 9) ? 'Enter your Ooredoo number' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    CheckboxListTile(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                      title: const Text('Keep me signed in on this phone'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (auth.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(auth.error!, style: TextStyle(color: scheme.error)),
                      ),
                    FilledButton(
                      onPressed: auth.busy ? null : _submit,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      child: auth.busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Log in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
