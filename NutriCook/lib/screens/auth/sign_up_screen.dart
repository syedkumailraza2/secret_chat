import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_text_field.dart';
import '../../widgets/primary_button.dart';
import 'auth_form_scaffold.dart';

/// Creating an account. The preference steps follow once this succeeds.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final created = await auth.signUp(
      email: _email.text,
      password: _password.text,
      displayName: _name.text,
    );

    // The root listens to AuthProvider and swaps to the preference steps on
    // its own; this screen only has to get out of the way.
    if (created && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthFormScaffold(
      title: 'Create your account',
      subtitle: 'So your recipes and preferences follow you anywhere.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthTextField(
                label: 'NAME',
                hint: 'What should we call you?',
                controller: _name,
                icon: Symbols.person,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                label: 'EMAIL',
                hint: 'you@example.com',
                controller: _email,
                icon: Symbols.mail,
                keyboardType: TextInputType.emailAddress,
                validator: AuthValidators.email,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                label: 'PASSWORD',
                hint: 'At least 8 characters',
                controller: _password,
                icon: Symbols.lock,
                obscure: true,
                validator: AuthValidators.newPassword,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                label: 'CONFIRM PASSWORD',
                hint: 'Once more',
                controller: _confirm,
                icon: Symbols.lock_reset,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (value) => value == _password.text
                    ? null
                    : "Those passwords don't match.",
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthErrorBanner(message: auth.error),
        PrimaryButton(
          label: 'Create Account',
          isLoading: auth.isBusy,
          onPressed: auth.isBusy ? null : _submit,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: auth.isBusy
                ? null
                : () => Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.logIn),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Already have an account? ',
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  TextSpan(
                    text: 'Log in',
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
