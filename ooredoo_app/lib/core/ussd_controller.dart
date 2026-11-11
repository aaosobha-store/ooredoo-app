import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import 'history_store.dart';
import 'ooredoo_api.dart';
import 'ooredoo_parser.dart';
import 'recent_numbers.dart';
import 'ussd_flow.dart';

/// Drives ONE USSD flow (Storm *580# or Bundle *585#).
class UssdController extends ChangeNotifier {
  UssdController({
    required this.api,
    required this.serviceCode,
    required this.kind,
    required this.history,
    this.ownNumber,
  });

  final OoredooApi api;
  final String serviceCode;
  final String kind; // 'storm' | 'bundle'
  final HistoryStore history;
  final String? ownNumber; // used when a bundle is bought for the logged-in number

  UssdFlow _flow = UssdFlow();
  String _sessionId = '';
  Timer? _timer;
  bool _disposed = false;
  bool _counted = false;

  UssdResponse? current;
  bool loading = false;
  bool finished = false;
  String? error;
  Receipt? receipt;
  int timeLeft = OoredooConfig.sessionSeconds;
  int step = 0; // changes on every reply (used to reset input fields)

  bool get active => current != null && !finished;

  Future<void> start() async {
    await api.pendingBalance; // never overlap with a balance check
    if (_disposed) return;
    await _send('1', isStart: true);
  }

  Future<void> choose(UssdOption o) => _send(o.id, choice: o);
  Future<void> submit(String value) => _send(value.trim());

  void reset() {
    _timer?.cancel();
    _release();
    _flow = UssdFlow();
    _sessionId = '';
    current = null;
    loading = false;
    finished = false;
    error = null;
    receipt = null;
    timeLeft = OoredooConfig.sessionSeconds;
    step++;
    notifyListeners();
  }

  void _release() {
    if (_counted) {
      _counted = false;
      api.activeFlows--;
    }
  }

  Future<void> _send(String msg, {bool isStart = false, UssdOption? choice}) async {
    if (loading || msg.isEmpty) return;
    if (isStart && !_counted) {
      _counted = true;
      api.activeFlows++;
    }
    loading = true;
    error = null;
    notifyListeners();

    final payload = {
      'app_id': OoredooConfig.appId,
      'service_code': isStart ? serviceCode : '',
      'msg': msg,
      'session_id': isStart ? '' : _sessionId,
      'session_continue': '1',
      'cache_enable': false,
    };

    try {
      final body = await api.nbservice(payload);
      if (_disposed) return;
      final parsed = parseOoredooResponse(body);
      _flow.record(msg: msg, response: parsed, choice: choice);

      if (!parsed.ok) {
        error = parsed.sessionLost
            ? 'Another USSD session replaced this one (did you dial from the phone?). Start again.'
            : 'Ooredoo error: ${parsed.message}';
        _finish();
      } else {
        current = parsed;
        step++;
        if (parsed.sessionId != null) _sessionId = parsed.sessionId!;

        if (parsed.kind == UssdKind.rejected) {
          error = parsed.mainText;
          _finish();
        } else if (parsed.ended) {
          receipt = _flow.toReceipt(parsed);
          _saveHistory();
          _finish();
        } else {
          _restartTimer();
        }
      }
    } on OoredooException catch (e) {
      if (_disposed) return;
      error = e.message;
      _finish();
    } catch (_) {
      if (_disposed) return;
      error = 'Unexpected error. Please try again.';
      _finish();
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void _saveHistory() {
    final r = receipt;
    if (r == null) return;
    final number = r.number ?? ownNumber;
    if (number == null || number.isEmpty) return;
    if (r.number != null) unawaited(RecentNumbers.add(r.number!));
    final now = DateTime.now();
    unawaited(history.add(HistoryEntry(
      id: '${now.microsecondsSinceEpoch}',
      at: now,
      type: kind,
      number: number,
      amount: r.amount,
      offer: r.offerLabel,
      operationId: r.operationId,
      loanPaid: r.loanPaid,
      loanAmount: r.loanAmount,
      forSelf: r.number == null,
    )));
  }

  void _finish() {
    finished = true;
    _timer?.cancel();
    _release();
  }

  void _restartTimer() {
    _timer?.cancel();
    timeLeft = OoredooConfig.sessionSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (loading || finished) return;
      timeLeft--;
      if (timeLeft <= 0) {
        error = 'The USSD session expired. Please start again.';
        _finish();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _release();
    super.dispose();
  }
}
