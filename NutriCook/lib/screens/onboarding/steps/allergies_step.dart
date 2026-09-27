import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/selection_card.dart';
import 'step_scaffold.dart';

/// onboarding4.html — multi-select allergies. "None" clears the rest.
class AllergiesStep extends StatelessWidget {
  final VoidCallback onContinue;

  const AllergiesStep({super.key, required this.onContinue});

  static const _options = <(String, IconData)>[
    ('Milk', Symbols.water_drop),
    ('Peanuts', Symbols.nutrition),
    ('Tree Nuts', Symbols.eco),
    ('Gluten', Symbols.grass),
    ('Soy', Symbols.local_florist),
    ('None', Symbols.check_circle),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final selected = user.preferences.allergies;

    return StepScaffold(
      title: 'Any allergies?',
      subtitle: 'Select all that apply so we can curate safe recipes for you.',
      centerTitle: true,
      footer: PrimaryButton(
        label: 'Continue',
        pill: true,
        // Allergies are optional, so this step never blocks.
        onPressed: onContinue,
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Two columns on phones, three once there is room, matching the
            // design's md: breakpoint.
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.05,
              children: [
                for (final (label, icon) in _options)
                  TileCard(
                    icon: icon,
                    label: label,
                    selected: selected.contains(label),
                    onTap: () =>
                        context.read<UserProvider>().toggleAllergy(label),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
