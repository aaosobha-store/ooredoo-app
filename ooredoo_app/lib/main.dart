import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth_store.dart';
import 'core/history_store.dart';
import 'core/pool_store.dart';
import 'core/ooredoo_api.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() => runApp(const OoredooApp());

class OoredooApp extends StatelessWidget {
  const OoredooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<OoredooApi>(create: (_) => OoredooApi()),
        ChangeNotifierProvider<AuthStore>(
          create: (ctx) => AuthStore(ctx.read<OoredooApi>())..init(),
        ),
        ChangeNotifierProvider<HistoryStore>(create: (_) => HistoryStore()..load()),
        ChangeNotifierProvider<PoolStore>(
          create: (ctx) => PoolStore(ctx.read<OoredooApi>())..load(),
        ),
      ],
      child: MaterialApp(
        title: 'Ooredoo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE30613)),
        ),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (auth.initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.loggedIn ? const HomeScreen() : const LoginScreen();
  }
}
