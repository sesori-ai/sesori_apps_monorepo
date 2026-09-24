import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// The signed-in account row: user avatar, the username, and one
/// "Signed in with `provider`" line led by the provider's icon.
///
/// Tappable (with a trailing chevron) when [onTap] is provided — the settings
/// screen navigates to the account screen; the account screen renders it
/// static.
///
/// The product shell supplies the current account from its authenticated
/// session owner, so this row remains presentation-only.
class const AccountRow({
  super.key,
  required final AuthUser account,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = _ProviderLine(provider: account.provider);
    final username = account.providerUsername;
    final hasUsername = username != null && username.isNotEmpty;

    return PregoGroupedRow(
      leading: const PregoAvatarUser(),
      title: hasUsername ? Text(username, overflow: TextOverflow.ellipsis) : provider,
      subtitle: hasUsername ? provider : null,
      trailing: onTap != null ? const Icon(TablerRegular.chevron_right) : null,
      onTap: onTap,
    );
  }
}

/// "Signed in with `provider`", led by the provider's icon.
class const _ProviderLine({required final AuthProvider provider}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: PregoSpacing.xs,
      children: [
        // The icon takes the colour of the line it leads, title or subtitle.
        Icon(_providerIcon(provider), size: PregoIconSize.sm, color: DefaultTextStyle.of(context).style.color),
        Flexible(
          child: Text(
            context.loc.settingsAccountSignedInWith(provider.label),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

IconData _providerIcon(AuthProvider provider) {
  return switch (provider) {
    GitHubAuthProvider() => TablerSolid.brand_github,
    GoogleAuthProvider() => VESPRSolid.google,
    AppleAuthProvider() => VESPRSolid.apple,
    EmailAuthProvider() => TablerRegular.mail,
  };
}
