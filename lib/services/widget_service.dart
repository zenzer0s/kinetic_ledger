import 'package:home_widget/home_widget.dart';
import 'rate_service.dart';

/// Pushes live rate data into the Android/iOS home screen widget via home_widget.
class WidgetService {
  static const _appGroupId = 'group.com.example.kinetic_ledger';
  static const _androidWidgetName =
      'com.example.kinetic_ledger.ZenithWidgetProvider';

  /// Call after fetching fresh rates to update the widget data + trigger redraw.
  static Future<void> updateWidget({
    required RatesResult rates,
    String fromCurrency = 'USD',
    String toCurrency = 'INR',
  }) async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      final fromMeta = metaFor(fromCurrency);
      final toMeta = metaFor(toCurrency);

      final crossRate = rates.crossRate(fromCurrency, toCurrency);
      final rateDisplay = _formatRate(crossRate, toCurrency);

      final changePercent = rates.changePercent;
      final isPositive = changePercent >= 0;
      final sign = isPositive ? '+' : '';
      final changeStr = '$sign${changePercent.toStringAsFixed(2)}%';

      final subLabel =
          '1 ${fromMeta.symbol} = ${toMeta.symbol}${crossRate.toStringAsFixed(crossRate >= 100 ? 2 : crossRate >= 1 ? 4 : 6)}';

      await HomeWidget.saveWidgetData<String>('rate', rateDisplay);
      await HomeWidget.saveWidgetData<String>('sub_label', subLabel);
      await HomeWidget.saveWidgetData<String>('change', changeStr);
      await HomeWidget.saveWidgetData<String>('updated', rates.updatedLabel);
      await HomeWidget.saveWidgetData<String>(
          'pair_label', '$fromCurrency → $toCurrency');
      await HomeWidget.saveWidgetData<String>(
          'flag_label', '${fromMeta.flag}→${toMeta.flag}');
      await HomeWidget.saveWidgetData<bool>('is_positive', isPositive);

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: 'ZenithWidget',
        qualifiedAndroidName: _androidWidgetName,
      );
    } catch (e) {
      // Widget update failures are non-critical — ignore silently
    }
  }

  static String _formatRate(double rate, String toCurrency) {
    if (toCurrency == 'JPY') return rate.toStringAsFixed(0);
    if (rate >= 100) return rate.toStringAsFixed(2);
    if (rate >= 1) return rate.toStringAsFixed(4);
    return rate.toStringAsFixed(6);
  }
}
