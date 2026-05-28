import "package:flutter/material.dart";
import "package:theme_zyra/components/buttons/zyra_buttons_solid.dart";
import "package:theme_zyra/icons/vespr_icons.g.dart";

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
        ZyraButtonsSolid(
          label: loc.loginWithGithub,
          hierarchy: ZyraButtonsSolidHierarchy.primaryAlt,
          size: ZyraButtonsSolidSize.xl,
          leadingIcon: VESPRSolid.github,
          isLoading: isLoading,
          fullWidth: true,
          onPressed: isLoading ? null : onGithubSelected,
        ),
        if (showApple) ...[
          const SizedBox(height: 12),
          ZyraButtonsSolid(
            label: loc.loginWithApple,
            hierarchy: ZyraButtonsSolidHierarchy.primaryAlt,
            size: ZyraButtonsSolidSize.xl,
            leadingIcon: VESPRSolid.apple,
            isLoading: isLoading,
            fullWidth: true,
            onPressed: isLoading ? null : onAppleSelected,
          ),
        ],
        const SizedBox(height: 12),
        ZyraButtonsSolid(
          label: loc.loginWithGoogle,
          hierarchy: ZyraButtonsSolidHierarchy.primaryAlt,
          size: ZyraButtonsSolidSize.xl,
          leadingIcon: VESPRSolid.google,
          isLoading: isLoading,
          fullWidth: true,
          onPressed: isLoading ? null : onGoogleSelected,
        ),
        if (!showEmailForm) ...[
          const SizedBox(height: 12),
          ZyraButtonsSolid(
            label: loc.signInWithEmail,
            hierarchy: ZyraButtonsSolidHierarchy.tertiary,
            size: ZyraButtonsSolidSize.xl,
            isLoading: isLoading,
            fullWidth: true,
            onPressed: isLoading ? null : onShowEmailForm,
          ),
        ],
      ],
    );
  }
}
