import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rate_service.dart';

final rateServiceProvider = Provider((ref) => RateService());

// Single shared provider — fetched once and kept alive so both screens
// always read the exact same rate value.
class RateNotifier extends AsyncNotifier<RateResult> {
  @override
  Future<RateResult> build() async {
    final service = ref.read(rateServiceProvider);
    
    // Check if we have a cached version to show something instantly
    final cached = await service.getCachedRate();
    if (cached != null) {
      // Return cached immediately, then fetch new one in background
      _fetchInBackground();
      return cached;
    }
    
    // If no cache, wait for fetch
    return await service.fetchRate();
  }

  Future<void> _fetchInBackground() async {
    final service = ref.read(rateServiceProvider);
    try {
      final fresh = await service.fetchRate();
      state = AsyncValue.data(fresh);
    } catch (e, _) {
      // Log error but keep showing the cached data if it was set
      debugPrint('Background fetch error: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(rateServiceProvider).fetchRate());
  }
}

final rateProvider = AsyncNotifierProvider<RateNotifier, RateResult>(RateNotifier.new);
