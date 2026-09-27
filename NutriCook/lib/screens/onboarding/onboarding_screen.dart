import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'steps/allergies_step.dart';
import 'steps/cuisines_step.dart';
import 'steps/diet_step.dart';
import 'steps/goal_step.dart';

/// Hosts the four preference steps, shown once an account exists.
///
/// The HTML files disagree on the progress indicator (four segments on the
/// goal step, none on the diet step, a single 80% bar on allergies, five
/// segments on cuisines). Normalised here to one indicator with a segment per
/// step — four of them, since onboarding1's welcome hero is now the sign-in
/// front door rather than a step in this flow.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _saving = false;

  static const int _stepCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _stepCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_page == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Saves the answers to the account, then lets the root swap to the app.
  ///
  /// `onboarding_complete` lives on the server now, so a failed write has to
  /// be surfaced rather than swallowed — otherwise the user is walked into
  /// the app and asked these same questions again on their next launch.
  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    final user = context.read<UserProvider>();
    final saved = await user.completeOnboarding();

    if (!mounted) return;
    setState(() => _saving = false);

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.inverseSurface,
          behavior: SnackBarBehavior.floating,
          content: Text(
            AppMessages.networkError,
            style: AppTextStyles.small.copyWith(
              color: AppColors.inverseOnSurface,
            ),
          ),
          action: SnackBarAction(
            label: AppMessages.tryAgain,
            textColor: AppColors.primaryFixed,
            onPressed: _finish,
          ),
        ),
      );
      return;
    }

    context.read<AuthProvider>().markOnboardingComplete(user.preferences);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _OnboardingHeader(
            step: _page,
            stepCount: _stepCount,
            // Nothing to go back to from the first step: the account already
            // exists, so there is no earlier screen in this flow.
            onBack: _page > 0 ? _back : null,
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              // Steps gate the Continue button, so swiping past them would
              // skip required choices.
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                GoalStep(onContinue: _next),
                DietStep(onContinue: _next),
                AllergiesStep(onContinue: _next),
                CuisinesStep(onContinue: _next),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  final int step;
  final int stepCount;

  /// Null on the first step, where the circle is held as a spacer so the
  /// wordmark stays centred.
  final VoidCallback? onBack;

  const _OnboardingHeader({
    required this.step,
    required this.stepCount,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.margin,
          AppSpacing.sm,
          AppSpacing.margin,
          AppSpacing.md,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Opacity(
                  opacity: onBack == null ? 0 : 1,
                  child: GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.arrow_back,
                        size: 20,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'NutriCook',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h1.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ProgressSteps(current: step, total: stepCount),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'STEP ${step + 1} OF $stepCount',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The segmented progress indicator, one segment per step.
class ProgressSteps extends StatelessWidget {
  final int current;
  final int total;

  const ProgressSteps({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                decoration: BoxDecoration(
                  color: i <= current
                      ? AppColors.primaryContainer
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
