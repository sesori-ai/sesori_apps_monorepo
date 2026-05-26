import "package:flutter/material.dart";
import "package:flutter_svg/svg.dart";
import "package:theme_zyra/components/buttons/zyra_buttons_solid.dart";

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
          leadingIcon: SvgPicture.asset(
            "assets/svgs/github_icon.svg",
            width: 20,
            height: 20,
          ),
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
            leadingIcon: SvgPicture.asset(
              "assets/svgs/apple_icon.svg",
              width: 20,
              height: 20,
            ),
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
          // Closest Material approximation to the Figma "G" mark — the previous
          // implementation used a styled Text("G"), which ZyraButtonsSolid does
          // not support as a leading widget.
          leadingIcon: SvgPicture.asset(
            "assets/svgs/google_icon.svg",
            width: 20,
            height: 20,
          ),
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
