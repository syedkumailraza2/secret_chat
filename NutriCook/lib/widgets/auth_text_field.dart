import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';

/// A labelled field for the sign-in and sign-up forms.
///
/// Built from the same tokens as the rest of the app: the filled
/// `surfaceContainer` treatment of the search field on home.html, with the
/// 12px corner radius the onboarding CTAs use.
class AuthTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Iterable<String>? autofillHints;

  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint = '',
    this.icon = Symbols.mail,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onSubmitted,
    this.autofocus = false,
    this.autofillHints,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: widget.controller,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          autofocus: widget.autofocus,
          autofillHints: widget.autofillHints,
          autocorrect: false,
          enableSuggestions: !widget.obscure,
          style: AppTextStyles.body,
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.body.copyWith(
              color: AppColors.onSecondaryContainer,
            ),
            prefixIcon: Icon(
              widget.icon,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden ? Symbols.visibility : Symbols.visibility_off,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                  )
                : null,
            filled: true,
            fillColor: AppColors.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            border: _border(AppColors.surfaceContainer),
            enabledBorder: _border(AppColors.surfaceContainer),
            focusedBorder: _border(AppColors.primaryContainer),
            errorBorder: _border(AppColors.error),
            focusedErrorBorder: _border(AppColors.error),
            errorStyle: AppTextStyles.caption.copyWith(
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: BorderSide(color: color, width: 1.5),
      );
}

/// Shared field validators, so sign-up and sign-in agree on what counts as a
/// valid address and a usable password.
class AuthValidators {
  AuthValidators._();

  /// Deliberately loose: something@something.something. The server does the
  /// real check, and an over-strict client regex only ever rejects addresses
  /// that actually work.
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(text)) return "That doesn't look like an email.";
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter your password.';
    return null;
  }

  /// Matches the server's minimum, so a weak password fails here rather than
  /// after a round trip.
  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Choose a password.';
    if (text.length < 8) return 'Use at least 8 characters.';
    return null;
  }
}
