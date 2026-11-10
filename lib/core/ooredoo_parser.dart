import 'text_utils.dart';

/// Dart port of Ooredooparser.js (only the parts the mobile flow needs).
///
/// Raw shape: { code: 0, data: { text: [[id, text], ...], nb_session_id, session_continue } }
/// An entry with id "" is message text, any other id is a menu option.

enum UssdKind { error, rejected, rechargeSuccess, prompt, menu, message }

enum PromptType { loanDecision, confirm, pin, customerNumber, amount }

class UssdOption {
  const UssdOption(this.id, this.label);
  final String id;
  final String label;
  bool get isNav => id == '0' || id == '00';
}

class UssdResponse {
  bool ok = false;
  UssdKind kind = UssdKind.error;
  int? code;
  String message = '';
  String? errorCode; // session_lost | unauthorized | other
  String? sessionId;
  bool continues = false;
  String mainText = '';
  List<UssdOption> options = [];
  PromptType? promptType;

  String? subscriber;
  double? amount;
  String? operationId;
  double? loanAmount;
  String? loanService;
  double? transferAmount;
  String? transferTarget;
  double? debitAmount;
  String? rejectionReason;
  String? ussdCode;

  bool get ended => !continues;
  bool get sessionLost => errorCode == 'session_lost';
}

RegExp _re(String p) => RegExp(p, caseSensitive: false);

final _rechargeRe = _re(r'recharge de l.abonn\w*\s+(\d+)\s+(?:de\s+)?([\d.,]+)\s*dinar');
final _operationRe = _re(r'operation\s*:?\s*(\d+)');
final _loanRe = _re(r'emprunt non-?rembourse de\s*([\d.,]+)\s*da');
final _loanServiceRe = _re(r'de service\s+([^\n]+)');
final _transferRe = _re(r'transferer\s+([\d.,]+)\s*da\b.*?vers le numero\s+(\d+)');
final _debitRe = _re(r'(\d[\d.,]*)\s*da\b\.?\s*vous seront debites');
final _okNumRe = _re(r'OK num\s+(\d+)');
final _creditOnlyRe = _re(r'ne peut recevoir que du credit');
final _composeRe = _re(r'composer\s+(\*\d+#)');
final _failureRe = _re(
    r'ne peut(?:vent)?\b|impossible|echec|erreur|invalide|insuffisan|non autoris|refus|incorrect|pas eligible|desole|veuillez reessayer');

PromptType? _detectPrompt(String t) {
  if (_re(r'emprunt non-?rembourse').hasMatch(t)) return PromptType.loanDecision;
  if (_re(r'tapez 1 pour confirmer').hasMatch(t)) return PromptType.confirm;
  if (_re(r'code pin').hasMatch(t)) return PromptType.pin;
  if (_re(r'numero du client').hasMatch(t)) return PromptType.customerNumber;
  if (_re(r'somme a recharger|entrez le montant').hasMatch(t)) return PromptType.amount;
  return null;
}

UssdResponse parseOoredooResponse(dynamic input) {
  final r = UssdResponse();
  final body = asJsonMap(input);
  if (body == null) {
    r.message = 'Empty or invalid response.';
    return r;
  }

  r.code = body['code'] is num ? (body['code'] as num).toInt() : null;
  final data = asJsonMap(body['data']) ?? <String, dynamic>{};

  // nb_session_id is a number on some replies, a string on others; 0 = no session.
  final sid = data['nb_session_id']?.toString() ?? '';
  r.sessionId = (sid.isEmpty || sid == '0') ? null : sid;
  r.continues = (num.tryParse('${data['session_continue']}') ?? 0) == 1;

  if (r.code != 0) {
    r.message = (body['message'] ?? data['message'] ?? 'Unknown Ooredoo error.').toString();
    final raw = (body['message'] ?? body['error'] ?? data['message'] ?? '').toString();
    if (_re(r'MultipleNBSessions|SESSION_LOST').hasMatch(raw)) {
      r.errorCode = 'session_lost'; // another session replaced ours
    } else if (body['auth'] == false || _re(r'unauthor|401').hasMatch(raw)) {
      r.errorCode = 'unauthorized';
    } else {
      r.errorCode = 'other';
    }
    return r;
  }

  final lines = <String>[];
  final entries = data['text'] is List ? data['text'] as List : const [];
  for (final entry in entries) {
    final id = entry is List ? (entry.isNotEmpty ? entry[0] : '') : '';
    final text = entry is List ? (entry.length > 1 ? entry[1] : '') : entry;
    final label = (text ?? '').toString();
    final idStr = id?.toString() ?? '';
    if (idStr.isEmpty) {
      lines.add(label);
    } else {
      r.options.add(UssdOption(idStr, label.trim()));
    }
  }
  r.mainText = lines.join('\n').trim();

  // An "OK num ..." text with no options is a final reply.
  if (_re(r'OK num').hasMatch(r.mainText) && r.options.isEmpty) r.continues = false;

  r.ok = true;
  r.message = r.mainText;
  final t = stripAccents(r.mainText);

  final tx = _rechargeRe.firstMatch(t);
  if (tx != null) {
    r.kind = UssdKind.rechargeSuccess;
    r.subscriber = toLocalPhone(tx.group(1));
    r.amount = toNumber(tx.group(2)); // amount really charged (includes a paid loan)
    r.operationId = _operationRe.firstMatch(t)?.group(1);
    return r;
  }

  if (r.ended && !_re(r'OK num').hasMatch(t)) {
    final reason = _creditOnlyRe.hasMatch(t)
        ? 'credit_only'
        : (_failureRe.hasMatch(t) ? 'other' : null);
    if (reason != null) {
      r.kind = UssdKind.rejected;
      r.rejectionReason = reason;
      r.ussdCode = _composeRe.firstMatch(t)?.group(1);
      return r;
    }
  }

  final pt = _detectPrompt(t);
  if (pt != null) {
    r.kind = UssdKind.prompt;
    r.promptType = pt;
    if (pt == PromptType.loanDecision) {
      r.loanAmount = toNumber(_loanRe.firstMatch(t)?.group(1));
      r.loanService = _loanServiceRe.firstMatch(t)?.group(1)?.trim();
    } else if (pt == PromptType.confirm) {
      final m = _transferRe.firstMatch(t);
      if (m != null) {
        r.transferAmount = toNumber(m.group(1));
        r.transferTarget = toLocalPhone(m.group(2));
      }
    } else if (pt == PromptType.pin) {
      r.debitAmount = toNumber(_debitRe.firstMatch(t)?.group(1));
    }
    return r;
  }

  if (r.options.isNotEmpty) {
    r.kind = UssdKind.menu;
  } else {
    r.kind = UssdKind.message;
    r.subscriber = toLocalPhone(_okNumRe.firstMatch(r.mainText)?.group(1));
    r.operationId = _operationRe.firstMatch(t)?.group(1);
  }
  return r;
}
