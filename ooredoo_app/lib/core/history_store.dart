import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.at,
    required this.type,
    required this.number,
    this.amount,
    this.offer,
    this.operationId,
    this.loanPaid = false,
    this.loanAmount,
    this.forSelf = false,
  });

  final String id;
  final DateTime at;
  final String type; // 'storm' | 'bundle'
  final String number;
  final double? amount;
  final String? offer;
  final String? operationId;
  final bool loanPaid;
  final double? loanAmount;
  final bool forSelf; // bought for the logged-in number itself

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'type': type,
        'number': number,
        'amount': amount,
        'offer': offer,
        'operationId': operationId,
        'loanPaid': loanPaid,
        'loanAmount': loanAmount,
        'forSelf': forSelf,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: '${j['id']}',
        at: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
        type: '${j['type']}',
        number: '${j['number']}',
        amount: (j['amount'] as num?)?.toDouble(),
        offer: j['offer'] as String?,
        operationId: j['operationId'] as String?,
        loanPaid: j['loanPaid'] == true,
        loanAmount: (j['loanAmount'] as num?)?.toDouble(),
        forSelf: j['forSelf'] == true,
      );
}

/// Purchases made from this app, saved on the phone (Ooredoo has no history endpoint we use).
class HistoryStore extends ChangeNotifier {
  static const _key = 'history_v1';
  static const _max = 2000;

  List<HistoryEntry> entries = [];

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        entries = list
            .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
      }
    } catch (_) {
      entries = [];
    }
    notifyListeners();
  }

  Future<void> add(HistoryEntry e) async {
    entries.insert(0, e);
    if (entries.length > _max) entries = entries.take(_max).toList();
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    entries = [];
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
}
