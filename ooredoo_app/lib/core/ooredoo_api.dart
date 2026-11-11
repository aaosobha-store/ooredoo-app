import 'dart:async';

import 'package:dio/dio.dart';

import '../config.dart';
import 'text_utils.dart';

class OoredooException implements Exception {
  OoredooException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to Ooredoo directly from the phone (same endpoints your Node service uses).
/// Each user has their OWN Ooredoo account, so no shared-line lock is needed here.
class OoredooApi {
  OoredooApi()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (_) => true,
          headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 11)'},
        ));

  final Dio _dio;
  String? _cookie;
  String? _phone;
  String? _password;
  Future<void>? _loginFuture;

  bool get hasSession => _cookie != null;

  // Ooredoo allows ONE USSD session at a time per account (a second one kills the first).
  // A Storm/Bundle flow and a balance check must therefore never overlap.
  int activeFlows = 0;
  Future<void>? pendingBalance;
  bool get flowActive => activeFlows > 0;

  Future<void> login(String phone, String password) async {
    _phone = phone;
    _password = password;
    _cookie = null;
    try {
      await _ensureLogin();
    } catch (_) {
      clear();
      rethrow;
    }
  }

  void clear() {
    _cookie = null;
    _phone = null;
    _password = null;
  }

  Future<void> _ensureLogin() {
    _loginFuture ??= _performLogin().whenComplete(() => _loginFuture = null);
    return _loginFuture!;
  }

  Future<void> _performLogin() async {
    final Response res;
    try {
      res = await _dio.post(
        '${OoredooConfig.baseUrl}/login',
        data: {
          'app_id': OoredooConfig.appId,
          'username': _phone,
          'password': _password,
          'isdevice': false,
          'device': false,
          'lang': null,
          'app_revision': null,
        },
      );
    } on DioException catch (e) {
      throw OoredooException(_networkMessage(e));
    }

    final body = asJsonMap(res.data);
    if (body == null || body['code'] != 0) {
      throw OoredooException(
          (body?['message'] ?? 'Login failed. Check your number and password.').toString());
    }

    final cookies = res.headers['set-cookie'];
    if (cookies == null || cookies.isEmpty) {
      throw OoredooException('Login succeeded but Ooredoo returned no session.');
    }
    _cookie = cookies.map((c) => c.split(';').first).join('; ');
  }

  Future<void> _relogin() {
    if (_phone == null || _password == null) {
      throw OoredooException('Session expired. Please log in again.');
    }
    return _ensureLogin();
  }

  Future<Response> _post(Map<String, dynamic> payload) async {
    try {
      return await _dio.post(
        '${OoredooConfig.baseUrl}/nbservice',
        data: payload,
        options: Options(headers: {'Accept': 'application/json', 'Cookie': _cookie}),
      );
    } on DioException catch (e) {
      throw OoredooException(_networkMessage(e));
    }
  }

  bool _isExpired(Response r) {
    if (r.statusCode == 401) return true;
    final d = asJsonMap(r.data);
    if (d == null) return false;
    if (d['code'] == 401 || d['auth'] == false) return true;
    final m = (d['message'] ?? '').toString().toLowerCase();
    return m.contains('unauthor') || m.contains('expire');
  }

  /// Sends one USSD step. If Ooredoo rejected the cookie, logs in again silently and retries once.
  Future<Map<String, dynamic>> nbservice(Map<String, dynamic> payload) async {
    if (_cookie == null) await _relogin();
    var res = await _post(payload);
    if (_isExpired(res)) {
      _cookie = null;
      await _relogin();
      res = await _post(payload);
    }
    return asJsonMap(res.data) ?? {'code': -1, 'message': 'Invalid response from Ooredoo.'};
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Ooredoo took too long to answer. Please try again.';
      case DioExceptionType.connectionError:
        return 'No connection to Ooredoo. Check your internet.';
      default:
        return 'Network error. Please try again.';
    }
  }
}
