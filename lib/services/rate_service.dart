import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Currency metadata ──────────────────────────────────────────────────────────
class CurrencyMeta {
  final String code;
  final String symbol;
  final String name;
  final String flag;

  const CurrencyMeta({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
  });
}

const List<CurrencyMeta> kTopCurrencies = [
  CurrencyMeta(code: 'USD', symbol: '\$', name: 'US Dollar', flag: '🇺🇸'),
  CurrencyMeta(code: 'EUR', symbol: '€', name: 'Euro', flag: '🇪🇺'),
  CurrencyMeta(code: 'GBP', symbol: '£', name: 'Pound', flag: '🇬🇧'),
  CurrencyMeta(code: 'JPY', symbol: '¥', name: 'Yen', flag: '🇯🇵'),
  CurrencyMeta(code: 'CHF', symbol: 'Fr', name: 'Franc', flag: '🇨🇭'),
  CurrencyMeta(code: 'AUD', symbol: 'A\$', name: 'AUD', flag: '🇦🇺'),
  CurrencyMeta(code: 'CAD', symbol: 'C\$', name: 'CAD', flag: '🇨🇦'),
  CurrencyMeta(code: 'SGD', symbol: 'S\$', name: 'SGD', flag: '🇸🇬'),
  CurrencyMeta(code: 'HKD', symbol: 'HK\$', name: 'HKD', flag: '🇭🇰'),
  CurrencyMeta(code: 'INR', symbol: '₹', name: 'Rupee', flag: '🇮🇳'),
];

CurrencyMeta metaFor(String code) => kTopCurrencies.firstWhere(
  (c) => c.code == code,
  orElse: () => CurrencyMeta(code: code, symbol: code, name: code, flag: '🌐'),
);

// ── Rate result model ──────────────────────────────────────────────────────────
class RatesResult {
  /// All rates expressed as "1 USD = X currency"
  final Map<String, double> rates;
  final String date;
  final double changePercent; // daily % change for USD→INR (default pair)

  RatesResult({
    required this.rates,
    required this.date,
    required this.changePercent,
  });

  // Backwards-compat getter for old code expecting .rate (USD→INR)
  double get rate => rates['INR'] ?? 84.0;

  String get updatedLabel {
    final d = DateTime.tryParse(date);
    if (d == null) return 'updated $date';
    final today = DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'updated today';
    }
    return 'updated $date';
  }

  /// Get the cross rate: 1 [from] = X [to]
  double crossRate(String from, String to) {
    if (from == 'USD') return rates[to] ?? 1.0;
    if (to == 'USD') return 1.0 / (rates[from] ?? 1.0);
    // Route through USD
    final fromRate = rates[from] ?? 1.0;
    final toRate = rates[to] ?? 1.0;
    return toRate / fromRate;
  }

  /// Daily change % for from→to pair
  double pairChangePercent(
    String from,
    String to,
    Map<String, double> yesterdayRates,
  ) {
    if (yesterdayRates.isEmpty) return changePercent;
    final todayRate = crossRate(from, to);
    double yesterdayFrom = from == 'USD'
        ? 1.0
        : 1.0 / (yesterdayRates[from] ?? 1.0);
    double yesterdayTo = to == 'USD' ? 1.0 : (yesterdayRates[to] ?? 1.0);
    final yesterdayRate = yesterdayFrom == 1.0
        ? yesterdayTo
        : yesterdayTo / (yesterdayRates[from] ?? 1.0);
    if (yesterdayRate == 0) return 0;
    return ((todayRate - yesterdayRate) / yesterdayRate) * 100;
  }
}

// ── Sparkline model ────────────────────────────────────────────────────────────
class SparklineResult {
  final List<double> points; // 7 daily rates
  final double minVal;
  final double maxVal;

  SparklineResult({
    required this.points,
    required this.minVal,
    required this.maxVal,
  });
}

// ── Service ────────────────────────────────────────────────────────────────────
class RateService {
  static const _base = 'https://api.frankfurter.app';
  static const _allCurrencies = 'EUR,GBP,JPY,CHF,AUD,CAD,SGD,HKD,INR';

  // ── Cache helpers ────────────────────────────────────────────────────────────
  Future<RatesResult?> getCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('cached_rates_json');
    final date = prefs.getString('cached_date');
    final change = prefs.getDouble('cached_change') ?? 0.0;
    if (json != null && date != null) {
      final map = (jsonDecode(json) as Map).cast<String, double>();
      return RatesResult(rates: map, date: date, changePercent: change);
    }
    return null;
  }

  Future<void> _cacheRates(RatesResult r) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_rates_json', jsonEncode(r.rates));
    await prefs.setString('cached_date', r.date);
    await prefs.setDouble('cached_change', r.changePercent);
  }

  // ── Fetch current + yesterday for daily change ──────────────────────────────
  Future<RatesResult> fetchRates() async {
    try {
      // Today
      final todayRes = await http.get(
        Uri.parse('$_base/latest?from=USD&to=$_allCurrencies'),
      );
      if (todayRes.statusCode != 200) {
        throw Exception('HTTP ${todayRes.statusCode}');
      }
      final todayData = jsonDecode(todayRes.body) as Map<String, dynamic>;
      final todayRatesRaw = (todayData['rates'] as Map).cast<String, dynamic>();
      final Map<String, double> rates = {
        'USD': 1.0,
        ...todayRatesRaw.map((k, v) => MapEntry(k, (v as num).toDouble())),
      };
      final date = todayData['date'] as String;

      // Yesterday (for daily % change)
      double changePercent = 0.0;
      try {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yStr =
            '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
        final yRes = await http.get(
          Uri.parse('$_base/$yStr?from=USD&to=$_allCurrencies'),
        );
        if (yRes.statusCode == 200) {
          final yData = jsonDecode(yRes.body) as Map<String, dynamic>;
          final yRates = (yData['rates'] as Map).cast<String, dynamic>();
          final todayINR = rates['INR'] ?? 84.0;
          final yINR = (yRates['INR'] as num?)?.toDouble() ?? todayINR;
          if (yINR != 0) changePercent = ((todayINR - yINR) / yINR) * 100;
        }
      } catch (_) {}

      final result = RatesResult(
        rates: rates,
        date: date,
        changePercent: changePercent,
      );
      await _cacheRates(result);
      return result;
    } catch (_) {
      final cached = await getCachedRates();
      if (cached != null) return cached;
      rethrow;
    }
  }

  // ── Historical sparkline (7 days) ───────────────────────────────────────────
  Future<SparklineResult> fetchSparkline(String from, String to) async {
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 8));
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final currencies = <String>{};
      if (from != 'USD') currencies.add(from);
      if (to != 'USD') currencies.add(to);
      final queryTo = currencies.isEmpty ? 'INR' : currencies.join(',');

      final res = await http.get(
        Uri.parse('$_base/${fmt(start)}..${fmt(end)}?from=USD&to=$queryTo'),
      );

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final ratesMap = (data['rates'] as Map<String, dynamic>);

      final sorted = ratesMap.keys.toList()..sort();
      final points = <double>[];

      for (final dateKey in sorted) {
        final dayRates = (ratesMap[dateKey] as Map).cast<String, dynamic>();
        double rate;
        if (from == 'USD') {
          rate = (dayRates[to] as num?)?.toDouble() ?? 0.0;
        } else if (to == 'USD') {
          final fromRate = (dayRates[from] as num?)?.toDouble() ?? 1.0;
          rate = fromRate == 0 ? 0 : 1.0 / fromRate;
        } else {
          final fromRate = (dayRates[from] as num?)?.toDouble() ?? 1.0;
          final toRate = (dayRates[to] as num?)?.toDouble() ?? 1.0;
          rate = fromRate == 0 ? 0 : toRate / fromRate;
        }
        if (rate > 0) points.add(rate);
      }

      if (points.isEmpty) return _fallbackSparkline();
      final minVal = points.reduce((a, b) => a < b ? a : b);
      final maxVal = points.reduce((a, b) => a > b ? a : b);
      return SparklineResult(points: points, minVal: minVal, maxVal: maxVal);
    } catch (_) {
      return _fallbackSparkline();
    }
  }

  SparklineResult _fallbackSparkline() {
    const pts = [30.0, 25.0, 32.0, 18.0, 22.0, 16.0, 14.0];
    return SparklineResult(
      points: pts,
      minVal: pts.reduce((a, b) => a < b ? a : b),
      maxVal: pts.reduce((a, b) => a > b ? a : b),
    );
  }
}
