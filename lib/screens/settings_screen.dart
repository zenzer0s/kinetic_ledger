import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/cerebras_service.dart';
import '../services/news_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zc = context.zc;
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: zc.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: zc.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SETTINGS',
          style: GoogleFonts.chakraPetch(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: zc.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [zc.accent.withValues(alpha: 0.05), zc.bg],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            // ── APPEARANCE ───────────────────────────────────────────────────
            _SettingsGroup(
              title: 'APPEARANCE',
              zc: zc,
              children: [
                _SettingsTile(
                  title: 'Dark Mode',
                  subtitle: isDark ? 'Sleek & Professional' : 'Bright & Clear',
                  icon: isDark
                      ? Icons.nightlight_round
                      : Icons.wb_sunny_rounded,
                  zc: zc,
                  trailing: _ZenithToggle(
                    value: isDark,
                    onChanged: (_) {
                      HapticFeedback.mediumImpact();
                      ref.read(themeProvider.notifier).toggle();
                    },
                    zc: zc,
                  ),
                ),
                _SettingsTile(
                  title: 'Accent Color',
                  subtitle: 'Zenith Signature Purple',
                  icon: Icons.palette_rounded,
                  zc: zc,
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: zc.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: zc.accent.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── NOTIFICATIONS ────────────────────────────────────────────────
            _SettingsGroup(
              title: 'ALERTS & SIGNALS',
              zc: zc,
              children: [
                _SettingsTile(
                  title: '15 Min Warning',
                  subtitle: 'Early prep for high impact',
                  icon: Icons.notifications_active_outlined,
                  zc: zc,
                  trailing: _ZenithToggle(
                    value: settings.alert15Min,
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateSettings(settings.copyWith(alert15Min: val));
                    },
                    zc: zc,
                  ),
                ),
                _SettingsTile(
                  title: '5 Min Warning',
                  subtitle: 'Final execution alert',
                  icon: Icons.timer_outlined,
                  zc: zc,
                  trailing: _ZenithToggle(
                    value: settings.alert5Min,
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateSettings(settings.copyWith(alert5Min: val));
                    },
                    zc: zc,
                  ),
                ),
                _SettingsTile(
                  title: 'Daily Digest',
                  subtitle: 'Morning summary @ 7 AM',
                  icon: Icons.auto_awesome_rounded,
                  zc: zc,
                  trailing: _ZenithToggle(
                    value: settings.dailyDigest,
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateSettings(settings.copyWith(dailyDigest: val));
                    },
                    zc: zc,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── CALENDAR ─────────────────────────────────────────────────────
            _SettingsGroup(
              title: 'CALENDAR PREFERENCES',
              zc: zc,
              children: [
                _SettingsTile(
                  title: 'Impcat Filter',
                  subtitle: settings.impactFilter.toUpperCase(),
                  icon: Icons.filter_alt_outlined,
                  zc: zc,
                  onTap: () {
                    _showImpactPicker(context, ref, settings, zc);
                  },
                ),
                _SettingsTile(
                  title: 'Trade Currencies',
                  subtitle: settings.currencyFilters.length == 8
                      ? 'ALL MAJOR'
                      : '${settings.currencyFilters.length} Selected',
                  icon: Icons.currency_exchange_rounded,
                  zc: zc,
                  onTap: () {
                    _showCurrencyPicker(context, ref, settings, zc);
                  },
                ),
                _SettingsTile(
                  title: 'Cache Validity',
                  subtitle: '${settings.cacheDurationHours} Hours',
                  icon: Icons.speed_rounded,
                  zc: zc,
                  onTap: () {
                    _showCacheDurationPicker(context, ref, settings, zc);
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── DATA MANAGEMENT ──────────────────────────────────────────────
            _SettingsGroup(
              title: 'DATA MGMT',
              zc: zc,
              children: [
                _SettingsTile(
                  title: 'Clear AI Cache',
                  subtitle: 'Clears LLM sentiment analysis',
                  icon: Icons.psychology_outlined,
                  zc: zc,
                  onTap: () async {
                    HapticFeedback.heavyImpact();
                    await CerebrasSentimentService.clearAllCaches();
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(_buildSnackBar(zc, 'AI Cache Cleared'));
                    }
                  },
                ),
                _SettingsTile(
                  title: 'Reset Calendar',
                  subtitle: 'Refetches all economic data',
                  icon: Icons.event_repeat_rounded,
                  zc: zc,
                  onTap: () async {
                    HapticFeedback.heavyImpact();
                    await NewsService.clearCalendarCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        _buildSnackBar(zc, 'Calendar Cache Cleared'),
                      );
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 48),

            // ── ABOUT ────────────────────────────────────────────────────────
            Column(
              children: [
                Text(
                  'ZENITH V1.0.0',
                  style: GoogleFonts.chakraPetch(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: zc.textDim,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Engineered for Peak Performance',
                  style: GoogleFonts.chakraPetch(
                    fontSize: 11,
                    color: zc.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showImpactPicker(
    BuildContext context,
    WidgetRef ref,
    ZenithSettings settings,
    ZenithColors zc,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: zc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: zc.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _PickerTile(
              label: 'HIGH ONLY',
              selected: settings.impactFilter == 'high',
              zc: zc,
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .updateSettings(settings.copyWith(impactFilter: 'high'));
                Navigator.pop(ctx);
              },
            ),
            _PickerTile(
              label: 'MED & HIGH',
              selected: settings.impactFilter == 'med_high',
              zc: zc,
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .updateSettings(
                      settings.copyWith(impactFilter: 'med_high'),
                    );
                Navigator.pop(ctx);
              },
            ),
            _PickerTile(
              label: 'SHOW ALL',
              selected: settings.impactFilter == 'all',
              zc: zc,
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .updateSettings(settings.copyWith(impactFilter: 'all'));
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    ZenithSettings settings,
    ZenithColors zc,
  ) {
    const majors = ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD'];

    showModalBottomSheet(
      context: context,
      backgroundColor: zc.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Container(
          padding: const EdgeInsets.only(bottom: 20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: zc.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SELECTED CURRENCIES',
                        style: GoogleFonts.chakraPetch(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: zc.textDim,
                          letterSpacing: 1.0,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final currentList = List<String>.from(
                            settings.currencyFilters,
                          );
                          if (currentList.length == majors.length) {
                            ref
                                .read(settingsProvider.notifier)
                                .updateSettings(
                                  settings.copyWith(currencyFilters: ['USD']),
                                );
                          } else {
                            ref
                                .read(settingsProvider.notifier)
                                .updateSettings(
                                  settings.copyWith(
                                    currencyFilters: List.from(majors),
                                  ),
                                );
                          }
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          settings.currencyFilters.length == majors.length
                              ? 'DESELECT'
                              : 'SELECT ALL',
                          style: GoogleFonts.chakraPetch(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: zc.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...majors.map((m) {
                  final contains = settings.currencyFilters.contains(m);
                  return CheckboxListTile(
                    title: Text(
                      m,
                      style: GoogleFonts.chakraPetch(
                        fontWeight: FontWeight.w600,
                        color: zc.textPrimary,
                      ),
                    ),
                    value: contains,
                    activeColor: zc.accent,
                    checkColor: Colors.white,
                    onChanged: (val) {
                      final newList = List<String>.from(
                        settings.currencyFilters,
                      );
                      if (val == true && !newList.contains(m)) {
                        newList.add(m);
                      } else if (val == false && newList.length > 1) {
                        // keep at least 1
                        newList.remove(m);
                      }
                      ref
                          .read(settingsProvider.notifier)
                          .updateSettings(
                            settings.copyWith(currencyFilters: newList),
                          );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCacheDurationPicker(
    BuildContext context,
    WidgetRef ref,
    ZenithSettings settings,
    ZenithColors zc,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: zc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: zc.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _PickerTile(
              label: '1 HOUR',
              selected: settings.cacheDurationHours == 1,
              zc: zc,
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .updateSettings(settings.copyWith(cacheDurationHours: 1));
                Navigator.pop(ctx);
              },
            ),
            _PickerTile(
              label: '4 HOURS (Balanced)',
              selected: settings.cacheDurationHours == 4,
              zc: zc,
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .updateSettings(settings.copyWith(cacheDurationHours: 4));
                Navigator.pop(ctx);
              },
            ),
            _PickerTile(
              label: '12 HOURS',
              selected: settings.cacheDurationHours == 12,
              zc: zc,
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .updateSettings(settings.copyWith(cacheDurationHours: 12));
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  SnackBar _buildSnackBar(ZenithColors zc, String msg) {
    return SnackBar(
      backgroundColor: zc.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(
        msg.toUpperCase(),
        style: GoogleFonts.chakraPetch(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final ZenithColors zc;

  const _SettingsGroup({
    required this.title,
    required this.children,
    required this.zc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.chakraPetch(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: zc.textDim,
              letterSpacing: 2.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: zc.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: zc.border),
          ),
          child: Column(
            children: children.asMap().entries.map((e) {
              final idx = e.key;
              final isLast = idx == children.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast) Divider(color: zc.border, height: 1, indent: 64),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final ZenithColors zc;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.zc,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: zc.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: zc.accent, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.chakraPetch(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: zc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.chakraPetch(
                      fontSize: 12,
                      color: zc.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _ZenithToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final ZenithColors zc;

  const _ZenithToggle({
    required this.value,
    required this.onChanged,
    required this.zc,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? zc.accent : zc.textDim.withValues(alpha: 0.1),
          border: Border.all(color: value ? zc.accent : zc.border),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          curve: Curves.easeOutBack,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final bool selected;
  final ZenithColors zc;
  final VoidCallback onTap;

  const _PickerTile({
    required this.label,
    required this.selected,
    required this.zc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: GoogleFonts.chakraPetch(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? zc.accent : zc.textPrimary,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: zc.accent, size: 20)
          : null,
    );
  }
}
