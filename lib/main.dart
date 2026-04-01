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
import 'screens/settings_screen.dart';
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
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _currentIndex = 0;
  final List<Widget> _screens = [
    const ConverterScreen(),
    const PercentageScreen(),
    const NewsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        physics: const BouncingScrollPhysics(),
        children: _screens,
      ),
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
                    Expanded(
                      child: _buildNavItem(
                        3, Icons.settings_suggest_rounded, 'ENGINE', zc),
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
          HapticFeedback.lightImpact();
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutQuart,
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            child: AnimatedContainer(
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

// ── Settings Button ───────────────────────────────────────────────────────────
// _SettingsButton removed as it's now a tab
