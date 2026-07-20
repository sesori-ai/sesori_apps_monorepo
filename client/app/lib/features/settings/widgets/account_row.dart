import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

/// The signed-in account row from the Figma settings redesign: user avatar,
/// username with an auth-provider tag, and the signed-in-with subtitle.
///
/// Tappable (with a trailing chevron) when [onTap] is provided — the settings
/// screen navigates to the profile screen; the profile screen renders it
/// static.
///
/// The account is sourced from `SettingsCubit` state (which subscribes to the
/// auth stream), so it stays in sync as the session resolves on launch.
class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.account,
    required this.onTap,
  });

  final AuthUser account;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final providerLabel = loc.settingsAccountSignedInWith(account.provider.label);
    final username = account.providerUsername;
    final hasUsername = username != null && username.isNotEmpty;

    return PregoGroupedRow(
      leading: const PregoAvatarUser(),
      title: Row(
        children: [
          Flexible(
            child: Text(
              hasUsername ? username : providerLabel,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: PregoSpacing.md),
          PregoTag(icon: _providerIcon(account.provider), label: account.provider.label),
        ],
      ),
      subtitle: hasUsername ? Text(providerLabel) : null,
      trailing: onTap != null ? const Icon(TablerRegular.chevron_right) : null,
      onTap: onTap,
      isLast: true,
    );
  }
}

IconData? _providerIcon(AuthProvider provider) {
  return switch (provider) {
    GitHubAuthProvider() => TablerSolid.brand_github,
    GoogleAuthProvider() => VESPRSolid.google,
    AppleAuthProvider() => VESPRSolid.apple,
    EmailAuthProvider() => null,
  };
}
