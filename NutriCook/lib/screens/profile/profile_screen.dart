import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/user_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/saved_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/secret_trigger.dart';

/// profile.html — avatar header plus the Nutrition, Preferences and Settings
/// bento cards.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text('Log out?', style: AppTextStyles.h2),
        content: Text(
          'Your recipes and preferences stay on your account — sign back in '
          'any time to pick up where you left off.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Log Out',
              style: AppTextStyles.h3.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Signing out flips AuthProvider to signedOut, and the root swaps to the
    // welcome screen on its own — no navigation from here, which is what
    // keeps a lapsed session and a deliberate log-out on the same path.
    await context.read<AuthProvider>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final account = context.watch<AuthProvider>().user;
    final prefs = user.preferences;
    final savedCount = context.watch<SavedProvider>().saved.length;

    final allergies = user.effectiveAllergies;
    final cuisines = user.effectiveCuisines;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.lg,
            AppSpacing.margin,
            BottomNavBar.reservedSpace(context) + AppSpacing.lg,
          ),
          children: [
            SecretTrigger(
              child: Text(
                'Your Profile',
                textAlign: TextAlign.center,
                style: AppTextStyles.h1,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 4),
                  boxShadow: AppShadows.soft,
                ),
                child: Center(
                  child: account == null
                      ? const Icon(
                          Symbols.person,
                          size: 44,
                          color: AppColors.onSurfaceVariant,
                        )
                      : Text(
                          account.initial,
                          style: AppTextStyles.displayLg.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              account?.displayName ?? 'NutriCook Chef',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3,
            ),
            if (account?.email != null)
              Text(
                account!.email!,
                textAlign: TextAlign.center,
                style: AppTextStyles.small.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            Text(
              '$savedCount saved ${savedCount == 1 ? 'recipe' : 'recipes'}',
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // --- Nutrition ---
            _BentoCard(
              icon: Symbols.monitor_weight,
              title: 'Nutrition',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'GOAL',
                          value: prefs.goal?.label ?? 'Not set',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _Stat(
                          label: 'DIET',
                          value: prefs.diet?.label ?? 'Not set',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Stat(
                    label: 'ALLERGIES',
                    value: allergies.isEmpty ? 'None' : allergies.join(', '),
                    muted: allergies.isEmpty,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // --- Preferences ---
            _BentoCard(
              icon: Symbols.cooking,
              title: 'Preferences',
              child: Column(
                children: [
                  _PreferenceRow(
                    label: 'Favorite Cuisines',
                    value: cuisines.isEmpty ? 'Anything' : cuisines.join(', '),
                  ),
                  const Divider(color: AppColors.surfaceVariant),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Default Serving Size',
                                style: AppTextStyles.body,
                              ),
                              Text(
                                '${prefs.defaultServings} '
                                '${prefs.defaultServings == 1 ? 'Person' : 'People'}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _ServingsControl(
                          value: prefs.defaultServings,
                          onChanged: (v) => context
                              .read<UserProvider>()
                              .setDefaultServings(v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // --- Settings ---
            _BentoCard(
              icon: Symbols.settings,
              title: 'Settings',
              child: Column(
                children: [
                  const _SettingRow(
                    icon: Symbols.straighten,
                    title: 'Units',
                    subtitle: 'Metric (g, ml, °C)',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SettingRow(
                    icon: Symbols.notifications,
                    title: 'Notifications',
                    subtitle: 'Push, Email',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SettingRow(
                    icon: Symbols.lock,
                    title: 'Privacy',
                    subtitle: 'Password, Data',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton(
                      onPressed: () => _confirmLogOut(context),
                      child: Text(
                        'Log Out',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _BentoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTextStyles.h2),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;

  const _Stat({
    required this.label,
    required this.value,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.normal),
        border: Border.all(
          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              color: muted
                  ? AppColors.onSurfaceVariant.withValues(alpha: 0.6)
                  : AppColors.onBackground,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreferenceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.body),
                Text(
                  value,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Symbols.chevron_right,
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.normal),
        border: Border.all(
          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Symbols.chevron_right,
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _ServingsControl extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _ServingsControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: value > 1 ? () => onChanged(value - 1) : null,
            child: Icon(
              Symbols.remove,
              size: 18,
              color: value > 1
                  ? AppColors.onSurface
                  : AppColors.outlineVariant,
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            alignment: Alignment.center,
            child: Text('$value', style: AppTextStyles.h3),
          ),
          GestureDetector(
            onTap: value < 12 ? () => onChanged(value + 1) : null,
            child: Icon(
              Symbols.add,
              size: 18,
              color: value < 12
                  ? AppColors.onSurface
                  : AppColors.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}
