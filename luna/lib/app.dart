import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/cycle_provider.dart';
import 'providers/log_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/luna_bottom_nav.dart';

class LunaApp extends StatelessWidget {
  const LunaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsProvider, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Luna',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // LockGate sits above the Navigator so it also covers sheets/dialogs.
      builder: (context, child) => LockGate(child: child ?? const SizedBox.shrink()),
      home: const _RootSwitcher(),
    );
  }
}

/// Shows onboarding until it is completed, then the main tab shell.
class _RootSwitcher extends StatelessWidget {
  const _RootSwitcher();

  @override
  Widget build(BuildContext context) {
    final done = context.select<SettingsProvider, bool>((s) => s.onboardingComplete);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: done ? const MainShell(key: ValueKey('shell')) : const OnboardingScreen(key: ValueKey('onboarding')),
    );
  }
}

/// Root navigation shell: Today, Calendar, Insights, Settings.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Lets screens switch tabs (e.g. Today's header → Calendar).
  static void goToTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<_MainShellState>()?.setTab(index);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _midnight;

  void setTab(int i) => setState(() => _index = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Day may have rolled over (or the clock changed) while backgrounded.
    if (state == AppLifecycleState.resumed) {
      _onDayChanged();
      _scheduleMidnight();
    }
  }

  /// Wakes just after local midnight so an app left open overnight moves
  /// its cycle day, "today" ring and today's log on to the new day.
  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    _midnight = Timer(next.difference(now), () {
      _onDayChanged();
      _scheduleMidnight();
    });
  }

  void _onDayChanged() {
    if (!mounted) return;
    context.read<CycleProvider>().refresh();
    context.read<LogProvider>().rollDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), CalendarScreen(), InsightsScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: LunaBottomNav(index: _index, onTap: setTab),
    );
  }
}

