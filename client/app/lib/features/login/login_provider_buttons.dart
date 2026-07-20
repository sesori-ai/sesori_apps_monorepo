import "package:flutter/material.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/icons/vespr_icons.g.dart";

import "../../../core/extensions/build_context_x.dart";

/// The login options whose button can show an in-flight loading spinner.
enum LoginOption { github, apple, google }

class LoginProviderButtons extends StatelessWidget {
  final bool isLoading;

  /// Which option's button swaps its provider logo for the loading spinner
  /// while [isLoading] is true. Null when the active flow was not started by
  /// one of these buttons (e.g. the email form).
  final LoginOption? loadingOption;
  final bool showEmailForm;
  final bool showApple;
  final VoidCallback onGithubSelected;
  final VoidCallback onAppleSelected;
  final VoidCallback onGoogleSelected;
  final VoidCallback onShowEmailForm;

  const LoginProviderButtons({
    super.key,
    required this.isLoading,
    required this.loadingOption,
    required this.showEmailForm,
    required this.showApple,
    required this.onGithubSelected,
    required this.onAppleSelected,
    required this.onGoogleSelected,
    required this.onShowEmailForm,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    // Taps are blocked at the pointer level instead of via `onPressed: null`
    // so the idle buttons keep their normal styling while a flow is in
    // flight — the design has no grayed-out state for them. AbsorbPointer
    // does not cover keyboard activation of a focused button, so the buttons
    // are also excluded from focus while loading.
    return ExcludeFocus(
      excluding: isLoading,
      child: AbsorbPointer(
        absorbing: isLoading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PregoButtonsSolid(
              label: loc.loginWithGithub,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.xl,
              leadingIcon: VESPRSolid.github,
              isLoading: isLoading && loadingOption == LoginOption.github,
              fullWidth: true,
              onPressed: onGithubSelected,
            ),
            if (showApple) ...[
              const SizedBox(height: 12),
              PregoButtonsSolid(
                label: loc.loginWithApple,
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.xl,
                leadingIcon: VESPRSolid.apple,
                isLoading: isLoading && loadingOption == LoginOption.apple,
                fullWidth: true,
                onPressed: onAppleSelected,
              ),
            ],
            const SizedBox(height: 12),
            PregoButtonsSolid(
              label: loc.loginWithGoogle,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.xl,
              leadingIcon: VESPRSolid.google,
              isLoading: isLoading && loadingOption == LoginOption.google,
              fullWidth: true,
              onPressed: onGoogleSelected,
            ),
            if (!showEmailForm) ...[
              const SizedBox(height: 12),
              PregoButtonsSolid(
                label: loc.signInWithEmail,
                hierarchy: PregoButtonsSolidHierarchy.tertiary,
                size: PregoButtonsSolidSize.xl,
                fullWidth: true,
                onPressed: onShowEmailForm,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
