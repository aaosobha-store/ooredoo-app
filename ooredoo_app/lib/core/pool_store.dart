import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'ooredoo_api.dart';
import 'ooredoo_parser.dart';

/// The Ooredoo pool: balances read live from Ooredoo (Storm account, loyalty points, bonus...).
class PoolStore extends ChangeNotifier {
  PoolStore(this.api);

  static const _key = 'pool_last';
  final OoredooApi api;

  PoolBalance? balance;
  bool loading = false;
  String? error;

  /// Shows the last known values immediately, before the first refresh finishes.
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        balance = PoolBalance.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        notifyListeners();
      }
    } catch (_) {}
  }

  /// [manual] = the user tapped refresh (show a message if a flow is open).
  Future<void> refresh({bool manual = false}) async {
    if (loading) return;
    if (api.flowActive) {
      if (manual) {
        error = 'Finish the current Storm/Bundle operation first.';
        notifyListeners();
      }
      return;
    }
    loading = true;
    error = null;
    notifyListeners();

    final job = _fetch();
    api.pendingBalance = job; // a Storm/Bundle flow opened now waits for this
    await job;
    if (identical(api.pendingBalance, job)) api.pendingBalance = null;

    loading = false;
    notifyListeners();
  }

  Future<void> _fetch() async {
    try {
      final body = await api.nbservice({
        'app_id': OoredooConfig.appId,
        'service_code': OoredooConfig.balanceCode,
        'msg': '1',
        'session_id': '',
        'session_continue': '1',
        'cache_enable': false,
      });
      final parsed = parseOoredooResponse(body);
      if (!parsed.ok) {
        error = 'Ooredoo error: ${parsed.message}';
      } else if (parsed.balance != null) {
        balance = parsed.balance;
        final p = await SharedPreferences.getInstance();
        await p.setString(_key, jsonEncode(parsed.balance!.toJson()));
      } else {
        error = 'Unexpected reply from Ooredoo: ${parsed.mainText}';
      }
    } on OoredooException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unexpected error while reading the pool.';
    }
  }
}
