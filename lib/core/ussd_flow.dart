import 'ooredoo_parser.dart';
import 'text_utils.dart';

class FlowChoice {
  FlowChoice(this.id, this.label, this.price);
  final String id;
  final String label;
  final double? price;
}

class Receipt {
  Receipt({
    this.number,
    this.amount,
    this.operationId,
    this.offerLabel,
    this.loanPaid = false,
    this.loanAmount,
    this.text = '',
  });
  final String? number;
  final double? amount;
  final String? operationId;
  final String? offerLabel;
  final bool loanPaid;
  final double? loanAmount;
  final String text;
}

// "GOLD 4000" -> 4000 ; "500 DA: 6Go + coupons" -> 500 ; "Forfait 100 (1jour)" -> 100
double? _priceFromLabel(String label) {
  final text = stripAccents(label);
  final withUnit = RegExp(r'(\d[\d.,]*)\s*(?:da|dinar|dzd)\b', caseSensitive: false).firstMatch(text);
  if (withUnit != null) return toNumber(withUnit.group(1));
  final cleaned = text.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  final nums = cleaned
      .split(RegExp(r'\s+'))
      .where((s) => RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(s))
      .toList();
  return nums.isEmpty ? null : toNumber(nums.last);
}

final _noiseChoice =
    RegExp(r'^(oui|non|confirmer|annuler|ok|retour|plus|suivant|precedent)$', caseSensitive: false);

/// Remembers what the user typed/picked during ONE USSD session, so a receipt can be built at the end.
/// The PIN is never stored.
class UssdFlow {
  String? customerNumber;
  double? requestedAmount;
  bool? loanPaid;
  double? loanAmount;
  double? debitAmount;
  final List<FlowChoice> choices = [];
  UssdResponse? _prev;

  void record({required String msg, required UssdResponse response, UssdOption? choice}) {
    _applyInput(msg, choice);
    if (response.loanAmount != null) loanAmount = response.loanAmount;
    if (response.debitAmount != null) debitAmount = response.debitAmount;
    _prev = response;
  }

  void _applyInput(String msg, UssdOption? choice) {
    final p = _prev; // the previous reply tells us what `msg` answers
    if (p == null) return;

    switch (p.promptType) {
      case PromptType.customerNumber:
        customerNumber = toLocalPhone(msg);
        return;
      case PromptType.amount:
        requestedAmount = toNumber(msg);
        return;
      case PromptType.pin:
        return; // never keep it
      case PromptType.loanDecision:
        UssdOption? opt;
        for (final o in p.options) {
          if (o.id == msg) opt = o;
        }
        loanPaid = opt != null && stripAccents(opt.label).trim().toLowerCase() == 'oui';
        return;
      default:
        break;
    }

    if (p.kind == UssdKind.menu && msg != '0' && msg != '00') {
      UssdOption? opt = (choice != null && choice.id == msg) ? choice : null;
      if (opt == null) {
        for (final o in p.options) {
          if (o.id == msg) {
            opt = o;
            break;
          }
        }
      }
      if (opt != null && !_noiseChoice.hasMatch(stripAccents(opt.label).trim())) {
        choices.add(FlowChoice(opt.id, opt.label.trim(), _priceFromLabel(opt.label)));
      }
    }
  }

  Receipt? toReceipt(UssdResponse last) {
    if (!last.ok || last.kind == UssdKind.rejected) return null;
    FlowChoice? priced;
    for (final c in choices.reversed) {
      if (c.price != null) {
        priced = c;
        break;
      }
    }
    final lastChoice = priced ?? (choices.isNotEmpty ? choices.last : null);
    return Receipt(
      number: last.subscriber ?? customerNumber,
      amount: last.amount ?? debitAmount ?? requestedAmount ?? priced?.price,
      operationId: last.operationId,
      offerLabel: lastChoice?.label,
      loanPaid: loanPaid == true,
      loanAmount: loanPaid == true ? loanAmount : null,
      text: last.mainText,
    );
  }
}
