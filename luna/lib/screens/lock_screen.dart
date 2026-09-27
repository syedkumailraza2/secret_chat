import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/biometric_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

/// Covers the app with [LockScreen] when the biometric lock is enabled:
/// on cold start, after returning from the background, and (as a blank
/// privacy cover) while the app is inactive / shown in the app switcher.
///
/// Mounted via `MaterialApp.builder`, so it sits above every route, sheet
/// and dialog. [child] stays mounted underneath to preserve its state.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late bool _locked;

  /// App is inactive (app switcher, control centre...) — hide content.
  bool _obscured = false;

  /// The system auth sheet itself makes the app inactive/paused; ignore
  /// lifecycle changes while it is up so it can't re-lock us in a loop.
  bool _authenticating = false;

  /// Prompt automatically on the next resume (set when we lock after
  /// being backgrounded, so a cancelled prompt doesn't reopen itself).
  bool _promptOnResume = false;

  bool get _enabled => context.read<SettingsProvider>().biometricLockEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = _enabled;
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authenticating || BiometricService.instance.inProgress || !_enabled) {
      if (_obscured) setState(() => _obscured = false);
      return;
    }
    switch (state) {
      case AppLifecycleState.inactive:
        setState(() => _obscured = true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        setState(() {
          _obscured = true;
          _locked = true;
          _promptOnResume = true;
        });
      case AppLifecycleState.resumed:
        setState(() => _obscured = false);
        if (_locked && _promptOnResume) {
          _promptOnResume = false;
          _unlock();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !mounted) return;
    _authenticating = true;
    final ok = await BiometricService.instance.authenticate(reason: 'Unlock Luna');
    // Let any trailing inactive→resumed from the system sheet settle first.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _authenticating = false;
    if (!mounted) return;
    setState(() {
      if (ok) _locked = false;
      _obscured = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        context.select<SettingsProvider, bool>((s) => s.biometricLockEnabled);
    final showLock = enabled && _locked;
    final showCover = enabled && _obscured && !showLock;

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: showLock || showCover,
          child: TickerMode(enabled: !showLock, child: widget.child),
        ),
        if (showLock)
          LockScreen(onUnlock: _unlock)
        else if (showCover)
          const _PrivacyCover(),
      ],
    );
  }
}

/// Plain branded cover used in the app switcher.
class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.surface,
      child: Center(child: Icon(Symbols.spa, weight: 200, size: 48, color: c.primaryContainer)),
    );
  }
}

class LockScreen extends StatelessWidget {
  const LockScreen({super.key, required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Icon(Symbols.spa, weight: 200, size: 56, color: c.primaryContainer),
              const SizedBox(height: AppSpacing.sm),
              Text('Luna',
                  style: AppText.headlineLg.copyWith(color: c.primaryContainer)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your cycle, kept private.',
                textAlign: TextAlign.center,
                style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: onUnlock,
                  icon: const Icon(Symbols.lock_open, weight: 200, size: 20),
                  label: const Text('Unlock'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primaryContainer,
                    foregroundColor: c.surface,
                    shape: const StadiumBorder(),
                    textStyle: AppText.labelLg,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
