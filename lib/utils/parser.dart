import 'package:intl/intl.dart';

class AmountParser {
  static Map<String, dynamic> parseAmount(String input) {
    if (input.isEmpty) return {'amount': 0.0, 'currency': 'USD'};

    String text = input.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    String currency = 'USD';
    
    if (text.endsWith('usd') || text.startsWith('\$') || text.endsWith('\$')) {
      currency = 'USD';
    } else if (text.endsWith('inr') || text.startsWith('₹') || text.endsWith('₹')) {
      currency = 'INR';
    }

    // Clean out non-numeric and multiplier characters
    String numPart = text
        .replaceAll(RegExp(r'usd|inr|\$|₹|lakh|crore|[k,l,c]'), '')
        .replaceAll(',', '');

    double amount = double.tryParse(numPart) ?? 0.0;

    if (text.contains('k')) {
      amount *= 1000;
    } else if (text.contains('l') || text.contains('lakh')) {
      amount *= 100000;
    } else if (text.contains('cr') || text.contains('crore') || text.contains('c')) {
      amount *= 10000000;
    }

    return {'amount': amount, 'currency': currency};
  }

  static String indianLabel(double n) {
    if (n >= 10000000) {
      return '${(n / 10000000).toStringAsFixed(2)} cr';
    } else if (n >= 100000) {
      return '${(n / 100000).toStringAsFixed(2)} lakh';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '';
  }

  static String formatINR(double amount) {
    return NumberFormat('#,##,##0.##', 'en_IN').format(amount);
  }

  static String formatUSD(double amount) {
    return NumberFormat('#,##0.##', 'en_US').format(amount);
  }
}
