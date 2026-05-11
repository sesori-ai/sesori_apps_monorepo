import "package:flutter/material.dart";
import "package:theme_zyra/module_zyra.dart";

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
    final zyra = context.zyra;
    final loc = context.loc;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: isLoading ? null : onGithubSelected,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.code_rounded, size: 20),
            label: Text(loc.loginWithGithub),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF24292F),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF24292F).withAlpha(153),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (showApple) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onAppleSelected,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.apple, size: 20),
              label: Text(loc.loginWithApple),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black.withAlpha(153),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onGoogleSelected,
            icon: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: zyra.colors.bgBrandSolid,
                    ),
                  )
                : Text(
                    "G",
                    style: zyra.textTheme.textMd.bold.copyWith(
                      fontSize: 20,
                      color: zyra.colors.textPrimary,
                    ),
                  ),
            label: Text(loc.loginWithGoogle),
            style: OutlinedButton.styleFrom(
              foregroundColor: zyra.colors.textPrimary,
              side: BorderSide(color: zyra.colors.borderPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!showEmailForm)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton(
              onPressed: isLoading ? null : onShowEmailForm,
              style: TextButton.styleFrom(
                foregroundColor: zyra.colors.bgBrandSolid,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(loc.continueWithEmail),
            ),
          ),
      ],
    );
  }
}
