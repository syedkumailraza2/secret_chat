import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/selection_card.dart';
import '../onboarding_images.dart';
import 'step_scaffold.dart';

/// onboarding5.html — multi-select cuisines. "Anything" clears the rest.
class CuisinesStep extends StatelessWidget {
  final VoidCallback onContinue;

  const CuisinesStep({super.key, required this.onContinue});

  static const _options = <(String, String?)>[
    ('Indian', OnboardingImages.indian),
    ('Italian', OnboardingImages.italian),
    ('Asian', OnboardingImages.asian),
    ('Mexican', OnboardingImages.mexican),
    ('Mediterranean', OnboardingImages.mediterranean),
    ('Anything', null),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final selected = user.preferences.cuisines;

    return StepScaffold(
      title: 'What do you like to eat?',
      subtitle: 'Select your favorite cuisines to help us personalize your '
          'culinary journey.',
      centerTitle: true,
      footer: PrimaryButton(label: 'Go to Home', onPressed: onContinue),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.2,
              children: [
                for (final (label, image) in _options)
                  ImageTileCard(
                    imageUrl: image,
                    label: label,
                    selected: selected.contains(label),
                    fallbackIcon:
                        image == null ? Symbols.restaurant_menu : null,
                    onTap: () =>
                        context.read<UserProvider>().toggleCuisine(label),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        // The design reveals this line once at least one cuisine is chosen.
        AnimatedOpacity(
          opacity: selected.isEmpty ? 0 : 1,
          duration: const Duration(milliseconds: 500),
          child: Text(
            'Let’s cook something great.',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}
