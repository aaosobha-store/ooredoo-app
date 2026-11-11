import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ooredoo_api.dart';

class AuthStore extends ChangeNotifier {
  AuthStore(this.api);

  final OoredooApi api;
  final _storage = const FlutterSecureStorage();

  bool initializing = true;
  bool loggedIn = false;
  bool busy = false;
  String? error;
  String? phone;
  String? savedPhone; // prefill for the login form

  Future<void> init() async {
    try {
      final p = await _storage.read(key: 'phone');
      final pw = await _storage.read(key: 'password');
      savedPhone = p;
      if (p != null && pw != null) {
        await api.login(p, pw);
        phone = p;
        loggedIn = true;
      }
    } catch (_) {
      // Offline or password changed: show the login form.
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String phoneInput, String password, {required bool remember}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final p = phoneInput.trim();
      await api.login(p, password);
      phone = p;
      loggedIn = true;
      if (remember) {
        await _storage.write(key: 'phone', value: p);
        await _storage.write(key: 'password', value: password);
      } else {
        await _storage.deleteAll();
      }
      return true;
    } on OoredooException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Unexpected error. Please try again.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    api.clear();
    await _storage.deleteAll();
    loggedIn = false;
    phone = null;
    notifyListeners();
  }
}
