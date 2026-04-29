import "package:flutter/material.dart";

import "../../../core/extensions/build_context_x.dart";

class LoginProviderButtons extends StatelessWidget {
  final bool isLoading;
  final bool showEmailForm;
  final VoidCallback onGithubSelected;
  final VoidCallback onGoogleSelected;
  final VoidCallback onShowEmailForm;

  const LoginProviderButtons({
    super.key,
    required this.isLoading,
    required this.showEmailForm,
    required this.onGithubSelected,
    required this.onGoogleSelected,
    required this.onShowEmailForm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Text(
                    "G",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
            label: Text(loc.loginWithGoogle),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              side: BorderSide(color: theme.colorScheme.outline),
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
                foregroundColor: theme.colorScheme.primary,
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
