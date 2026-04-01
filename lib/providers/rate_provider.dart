import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rate_service.dart';
import '../services/widget_service.dart';

final rateServiceProvider = Provider((ref) => RateService());

// ── All rates notifier ─────────────────────────────────────────────────────────
class RateNotifier extends AsyncNotifier<RatesResult> {
  @override
  Future<RatesResult> build() async {
    final service = ref.read(rateServiceProvider);
    final cached = await service.getCachedRates();
    if (cached != null) {
      _fetchInBackground();
      return cached;
    }
    return await service.fetchRates();
  }

  Future<void> _fetchInBackground() async {
    final service = ref.read(rateServiceProvider);
    try {
      final fresh = await service.fetchRates();
      state = AsyncValue.data(fresh);
      // Push latest data to home screen widget
      await WidgetService.updateWidget(rates: fresh);
    } catch (e, _) {
      debugPrint('Background fetch error: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => ref.read(rateServiceProvider).fetchRates(),
    );
    state = result;
    if (result.hasValue) {
      await WidgetService.updateWidget(rates: result.value!);
    }
  }
}

final rateProvider = AsyncNotifierProvider<RateNotifier, RatesResult>(
  RateNotifier.new,
);

// ── Yesterday rates provider (for per-pair % change) ─────────────────────────
final yesterdayRatesProvider = FutureProvider<Map<String, double>>((ref) async {
  final service = ref.read(rateServiceProvider);
  try {
    // Yesterday rates are embedded in RatesResult.changePercent from the service.
    // Per-pair change is computed in the UI via sparkline data.
    await service.fetchRates();
    return {};
  } catch (_) {
    return {};
  }
});

// ── Sparkline provider (family — keyed by "FROM_TO") ──────────────────────────
final sparklineProvider = FutureProvider.family<SparklineResult, String>((
  ref,
  pair,
) async {
  final parts = pair.split('_');
  final from = parts[0];
  final to = parts[1];
  final service = ref.read(rateServiceProvider);
  return service.fetchSparkline(from, to);
});
