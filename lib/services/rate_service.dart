import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RateResult {
  final double rate;
  final String date; // e.g. "2025-03-24"

  RateResult({required this.rate, required this.date});

  String get updatedLabel {
    final d = DateTime.tryParse(date);
    if (d == null) return 'updated $date';
    
    final today = DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'updated today';
    }
    return 'updated $date';
  }
}

class RateService {
  static const _url = 'https://api.frankfurter.app/latest?from=USD&to=INR';

  Future<RateResult?> getCachedRate() async {
    final prefs = await SharedPreferences.getInstance();
    final rate = prefs.getDouble('cached_rate');
    final date = prefs.getString('cached_date');
    if (rate != null && date != null) {
      return RateResult(rate: rate, date: date);
    }
    return null;
  }

  Future<RateResult> fetchRate() async {
    try {
      final res = await http.get(Uri.parse(_url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rate = (data['rates']['INR'] as num).toDouble();
        final date = data['date'] as String;
        
        // Cache it
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('cached_rate', rate);
        await prefs.setString('cached_date', date);
        
        return RateResult(rate: rate, date: date);
      }
    } catch (_) {
      // Return cached if fetch fails
      final cached = await getCachedRate();
      if (cached != null) return cached;
      rethrow;
    }
    
    final cached = await getCachedRate();
    if (cached != null) return cached;
    throw Exception('Failed to fetch rate and no cache available');
  }
}
