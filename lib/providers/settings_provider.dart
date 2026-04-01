import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ZenithSettings {
  final bool alert15Min;
  final bool alert5Min;
  final bool dailyDigest;
  final String impactFilter; // 'all', 'high', 'medium_high'
  final List<String> currencyFilters;
  final int cacheDurationHours;

  const ZenithSettings({
    this.alert15Min = true,
    this.alert5Min = true,
    this.dailyDigest = true,
    this.impactFilter = 'high',
    this.currencyFilters = const [
      'USD',
      'EUR',
      'GBP',
      'JPY',
      'AUD',
      'CAD',
      'CHF',
      'NZD',
    ],
    this.cacheDurationHours = 4,
  });

  ZenithSettings copyWith({
    bool? alert15Min,
    bool? alert5Min,
    bool? dailyDigest,
    String? impactFilter,
    List<String>? currencyFilters,
    int? cacheDurationHours,
  }) {
    return ZenithSettings(
      alert15Min: alert15Min ?? this.alert15Min,
      alert5Min: alert5Min ?? this.alert5Min,
      dailyDigest: dailyDigest ?? this.dailyDigest,
      impactFilter: impactFilter ?? this.impactFilter,
      currencyFilters: currencyFilters ?? this.currencyFilters,
      cacheDurationHours: cacheDurationHours ?? this.cacheDurationHours,
    );
  }
}

class SettingsNotifier extends Notifier<ZenithSettings> {
  static const _prefix = 'settings_';

  @override
  ZenithSettings build() {
    _load();
    return const ZenithSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ZenithSettings(
      alert15Min: prefs.getBool('${_prefix}alert15Min') ?? true,
      alert5Min: prefs.getBool('${_prefix}alert5Min') ?? true,
      dailyDigest: prefs.getBool('${_prefix}dailyDigest') ?? true,
      impactFilter: prefs.getString('${_prefix}impactFilter') ?? 'high',
      currencyFilters:
          prefs.getStringList('${_prefix}currencyFilters') ??
          const ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD'],
      cacheDurationHours: prefs.getInt('${_prefix}cacheDurationHours') ?? 4,
    );
  }

  Future<void> updateSettings(ZenithSettings newSettings) async {
    state = newSettings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefix}alert15Min', state.alert15Min);
    await prefs.setBool('${_prefix}alert5Min', state.alert5Min);
    await prefs.setBool('${_prefix}dailyDigest', state.dailyDigest);
    await prefs.setString('${_prefix}impactFilter', state.impactFilter);
    await prefs.setStringList(
      '${_prefix}currencyFilters',
      state.currencyFilters,
    );
    await prefs.setInt(
      '${_prefix}cacheDurationHours',
      state.cacheDurationHours,
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, ZenithSettings>(
  SettingsNotifier.new,
);
