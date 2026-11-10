import 'dart:convert';

const _accents = <String, String>{
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ç': 'c', 'œ': 'oe',
  'À': 'A', 'Â': 'A', 'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
  'Î': 'I', 'Ï': 'I', 'Ô': 'O', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', 'Ç': 'C',
};

/// "Fidélité" -> "Fidelite", so one regex matches both spellings.
String stripAccents(String s) => s.split('').map((c) => _accents[c] ?? c).join();

double? toNumber(String? raw) {
  if (raw == null) return null;
  var s = raw.replaceAll(RegExp(r'\s'), '').replaceAll(RegExp(r'[.,]+$'), '');
  if (s.contains(',') && s.contains('.')) {
    s = s.replaceAll(',', '');
  } else {
    s = s.replaceFirst(',', '.');
  }
  return double.tryParse(s);
}

/// 213551655644 -> 0551655644
String? toLocalPhone(String? raw) {
  final d = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('213') && d.length == 12) return '0${d.substring(3)}';
  return d.isEmpty ? null : d;
}

Map<String, dynamic>? asJsonMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

String formatDa(double? v) {
  if (v == null) return '—';
  return '${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)} DA';
}
