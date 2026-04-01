import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/percentage_screen.dart';
import 'screens/news_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.setAppGroupId('group.com.example.kinetic_ledger');

  // Init notification channels & request permission
  await NotificationService().init();
  await NotificationService().requestPermission();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: ZenithApp()));
}

class ZenithApp extends ConsumerWidget {
  const ZenithApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    // Sync status bar icons with theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ));

    return MaterialApp(
      title: 'Zenith',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainScaffold(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const ConverterScreen(),
    const PercentageScreen(),
    const NewsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final zc = context.zc;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: _screens[_currentIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: zc.navBar,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: zc.border,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    // ── Nav items ──────────────────────────────────────────
                    Expanded(
                      child: _buildNavItem(
                        0, Icons.currency_exchange_rounded, 'CONVERT', zc),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        1, Icons.calculate_rounded, 'CALC', zc),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        2, Icons.newspaper_rounded, 'PULSE', zc),
                    ),

                    // ── Theme Toggle ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _ThemeToggle(isDark: isDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, String label, ZenithColors zc) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          HapticFeedback.heavyImpact();
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? zc.accentSoft.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              color: isSelected ? zc.accentSoft : zc.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.chakraPetch(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: isSelected ? zc.accentSoft : zc.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated Theme Toggle ─────────────────────────────────────────────────────
class _ThemeToggle extends ConsumerWidget {
  final bool isDark;
  const _ThemeToggle({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zc = context.zc;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(themeProvider.notifier).toggle();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isDark
              ? zc.accent.withValues(alpha: 0.2)
              : const Color(0xFFFACC15).withValues(alpha: 0.2),
          border: Border.all(
            color: isDark
                ? zc.accent.withValues(alpha: 0.4)
                : const Color(0xFFFACC15).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Track icons
            Positioned(
              left: 7,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  Icons.nightlight_round,
                  size: 12,
                  color: isDark
                      ? zc.accent
                      : zc.textDim,
                ),
              ),
            ),
            Positioned(
              right: 7,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  Icons.wb_sunny_rounded,
                  size: 12,
                  color: isDark
                      ? zc.textDim
                      : const Color(0xFFFACC15),
                ),
              ),
            ),
            // Sliding thumb
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: isDark ? 3 : null,
              right: isDark ? null : 3,
              top: 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? zc.accent : const Color(0xFFFACC15),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? zc.accent : const Color(0xFFFACC15))
                          .withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    size: 12,
                    color: isDark ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
