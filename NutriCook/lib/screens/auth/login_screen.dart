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

/// Signing back in. Preferences and saved recipes come down with the account.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final signedIn = await auth.signIn(
      email: _email.text,
      password: _password.text,
    );

    if (signedIn && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthFormScaffold(
      title: 'Welcome back',
      subtitle: 'Your kitchen is just as you left it.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
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
                hint: 'Your password',
                controller: _password,
                icon: Symbols.lock,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: AuthValidators.password,
                onSubmitted: (_) => _submit(),
                autofillHints: const [AutofillHints.password],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthErrorBanner(message: auth.error),
        PrimaryButton(
          label: 'Log In',
          isLoading: auth.isBusy,
          onPressed: auth.isBusy ? null : _submit,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: auth.isBusy
                ? null
                : () => Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.signUp),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'New here? ',
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  TextSpan(
                    text: 'Create an account',
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
