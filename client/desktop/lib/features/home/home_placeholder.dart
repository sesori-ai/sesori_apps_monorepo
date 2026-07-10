import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Signed-in placeholder: bridge supervision controls land here with the
/// tray/window slices.
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({required this.user, super.key});

  final AuthUser user;

  static const String _signedInAs = "Signed in as";
  static const String _placeholderNote = "Bridge controls are on their way.";
  static const String _signOut = "Sign out";

  @override
  Widget build(BuildContext context) {
    final String? username = user.providerUsername?.trim();
    final String account = (username == null || username.isEmpty) ? user.providerUserId : username;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("$_signedInAs $account (${user.provider.label})"),
            const SizedBox(height: 8),
            Text(_placeholderNote, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => unawaited(context.read<AuthGateCubit>().signOut()),
              child: const Text(_signOut),
            ),
          ],
        ),
      ),
    );
  }
}
