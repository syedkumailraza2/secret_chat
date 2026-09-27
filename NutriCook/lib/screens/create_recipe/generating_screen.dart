import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/error_view.dart';

/// generating.html — the pulsing sous-chef and the five-step progress list.
///
/// Pops with `true` once recipes are ready, `false` if generation failed and
/// the user backs out.
class GeneratingScreen extends StatefulWidget {
  const GeneratingScreen({super.key});

  @override
  State<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<GeneratingScreen> {
  bool _popped = false;

  void _popIfDone(RecipeProvider provider) {
    if (_popped) return;
    if (provider.isGenerating) return;
    if (provider.generatedRecipes.isEmpty) return;

    _popped = true;
    // Let the final step render as complete before leaving.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      // Guard the pop: this route is always pushed, but popping the last
      // route would leave a blank window rather than fail loudly.
      if (navigator.canPop()) navigator.pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) => _popIfDone(provider));

    return PopScope(
      // Leaving mid-generation would strand the request, so back is disabled
      // until it resolves.
      canPop: !provider.isGenerating,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.margin,
                  vertical: AppSpacing.xl,
                ),
                child: provider.error != null
                    ? ErrorView(
                        message: provider.error!,
                        hint: provider.error,
                        onRetry: () => Navigator.of(context).pop(false),
                      )
                    : _Progress(provider: provider),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final RecipeProvider provider;

  const _Progress({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PulsingIcon(),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Crafting your menu',
          textAlign: TextAlign.center,
          style: AppTextStyles.h1,
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: 280,
          child: Text(
            'Our AI digital sous-chef is preparing something special.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        for (var i = 0; i < RecipeProvider.generationSteps.length; i++) ...[
          _StepRow(
            label: RecipeProvider.generationSteps[i],
            state: i < provider.currentStep
                ? _StepState.done
                : i == provider.currentStep
                    ? _StepState.active
                    : _StepState.pending,
          ),
          if (i < RecipeProvider.generationSteps.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  final String label;
  final _StepState state;

  const _StepRow({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: state == _StepState.pending ? 0.5 : 1,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: switch (state) {
              _StepState.done => Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Symbols.check,
                    size: 18,
                    color: AppColors.onPrimary,
                  ),
                ),
              _StepState.active => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryContainer,
                      width: 2,
                    ),
                  ),
                  child: const Center(child: _PulsingDot()),
                ),
              _StepState.pending => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.outlineVariant,
                      width: 2,
                    ),
                  ),
                ),
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.h3.copyWith(
                color: switch (state) {
                  _StepState.active => AppColors.primaryContainer,
                  _StepState.pending => AppColors.onSurfaceVariant,
                  _StepState.done => AppColors.onBackground,
                },
                fontWeight: state == _StepState.active
                    ? FontWeight.w700
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_controller),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// The expanding ring behind the magic icon.
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.8 + (t * 0.4),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer
                        .withValues(alpha: 0.2 * (1 - t)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Symbols.magic_button,
            size: 40,
            fill: 1,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
