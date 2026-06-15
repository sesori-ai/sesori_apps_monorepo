import "package:flutter/material.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/icons/vespr_icons.g.dart";

import "../../../core/extensions/build_context_x.dart";

class LoginProviderButtons extends StatelessWidget {
  final bool isLoading;
  final bool showEmailForm;
  final bool showApple;
  final VoidCallback onGithubSelected;
  final VoidCallback onAppleSelected;
  final VoidCallback onGoogleSelected;
  final VoidCallback onShowEmailForm;

  const LoginProviderButtons({
    super.key,
    required this.isLoading,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PregoButtonsSolid(
          label: loc.loginWithGithub,
          hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
          size: PregoButtonsSolidSize.xl,
          leadingIcon: VESPRSolid.github,
          isLoading: isLoading,
          fullWidth: true,
          onPressed: isLoading ? null : onGithubSelected,
        ),
        if (showApple) ...[
          const SizedBox(height: 12),
          PregoButtonsSolid(
            label: loc.loginWithApple,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            size: PregoButtonsSolidSize.xl,
            leadingIcon: VESPRSolid.apple,
            isLoading: isLoading,
            fullWidth: true,
            onPressed: isLoading ? null : onAppleSelected,
          ),
        ],
        const SizedBox(height: 12),
        PregoButtonsSolid(
          label: loc.loginWithGoogle,
          hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
          size: PregoButtonsSolidSize.xl,
          leadingIcon: VESPRSolid.google,
          isLoading: isLoading,
          fullWidth: true,
          onPressed: isLoading ? null : onGoogleSelected,
        ),
        if (!showEmailForm) ...[
          const SizedBox(height: 12),
          PregoButtonsSolid(
            label: loc.signInWithEmail,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            size: PregoButtonsSolidSize.xl,
            isLoading: isLoading,
            fullWidth: true,
            onPressed: isLoading ? null : onShowEmailForm,
          ),
        ],
      ],
    );
  }
}
