import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../models/user_preferences.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/selection_card.dart';
import 'step_scaffold.dart';

/// onboarding2.html — single-select lifestyle goal.
class GoalStep extends StatelessWidget {
  final VoidCallback onContinue;

  const GoalStep({super.key, required this.onContinue});

  static const _options = <(LifestyleGoal, IconData, String)>[
    (LifestyleGoal.eatHealthier, Symbols.nutrition,
        'Focus on nutritious, balanced meals.'),
    (LifestyleGoal.loseWeight, Symbols.monitor_weight,
        'Calorie-conscious recipes for your journey.'),
    (LifestyleGoal.buildMuscle, Symbols.fitness_center,
        'High-protein meals to fuel recovery.'),
    (LifestyleGoal.maintainWeight, Symbols.balance,
        'Sustain your current lifestyle with ease.'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final selected = user.preferences.goal;

    return StepScaffold(
      title: 'What’s your goal?',
      subtitle: 'Select your primary objective to help us personalize your '
          'culinary experience.',
      footer: PrimaryButton(
        label: 'Continue',
        onPressed: selected == null ? null : onContinue,
      ),
      children: [
        for (final (goal, icon, subtitle) in _options) ...[
          SelectionCard(
            icon: icon,
            title: goal.label,
            subtitle: subtitle,
            selected: selected == goal,
            onTap: () => context.read<UserProvider>().setGoal(goal),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
