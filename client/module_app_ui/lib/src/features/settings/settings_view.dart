import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../support/support_links.dart";
import "widgets/account_row.dart";
import "widgets/appearance_picker.dart";
import "widgets/bridge_settings_section.dart";
import "widgets/chat_input_mode_picker.dart";
import "widgets/settings_section.dart";

/// Vertical inset between the nav bar and the first settings section.
const double _contentTopPadding = 10.0;

/// Product-version data rendered in the settings footer.
///
/// Product shells adapt their platform package metadata into this UI-only
/// shape, keeping `package_info_plus` out of the shared screen package.
class const AppVersionInfo({
  required final String version,
  required final String buildNumber,
});

/// Shared settings landing view.
///
/// Product shells own route tables, dependency injection, package metadata,
/// and outbound-link policy. This view only renders those capabilities and
/// dispatches the callbacks supplied by its shell.
class const SettingsView({
  super.key,
  required final AuthUser? account,
  required final Widget? connectionBanner,
  required final VoidCallback onClose,
  required final VoidCallback onOpenProfile,
  required final VoidCallback? onOpenNotifications,
  required final VoidCallback onOpenHarnesses,
  required final Widget? additionalSettings,
  required final Future<void> Function({required Uri url}) openSupportLink,
  required final Future<void> Function({required LegalDocument document}) openLegalDocument,
  required final Future<AppVersionInfo?> Function() loadAppVersionInfo,
  required final Widget? footerLogo,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final account = this.account;
    final onOpenNotifications = this.onOpenNotifications;
    final additionalSettings = this.additionalSettings;

    return PregoGlassScaffold(
      title: loc.settingsTitle,
      banner: connectionBanner,
      onRefresh: () async {
        await context.read<BridgeSettingsCubit>().refresh();
      },
      automaticallyImplyLeading: false,
      actions: [
        PregoButtonsIconGlass(
          icon: TablerRegular.x,
          semanticLabel: loc.settingsClose,
          onPressed: onClose,
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PregoSpacing.xl,
              vertical: _contentTopPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSection(
                  title: loc.settingsSectionAccount,
                  child: PregoGroupedRows(
                    children: [
                      // The profile screen owns the only logout action, so its
                      // row must stay reachable even when the cached account
                      // is absent (valid tokens without a stored user).
                      if (account != null)
                        AccountRow(account: account, onTap: onOpenProfile)
                      else
                        PregoGroupedRow(
                          leading: const PregoAvatarUser(),
                          title: Text(loc.settingsProfileTitle),
                          trailing: const Icon(TablerRegular.chevron_right),
                          onTap: onOpenProfile,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: PregoSpacing.xl),
                PregoGroupedRows(
                  children: [
                    if (onOpenNotifications != null)
                      PregoGroupedRow(
                        icon: TablerRegular.bell,
                        title: Text(loc.settingsNotificationsTitle),
                        trailing: const Icon(TablerRegular.chevron_right),
                        onTap: onOpenNotifications,
                      ),
                    PregoGroupedRow(
                      icon: TablerRegular.plug,
                      title: Text(loc.settingsHarnessesTitle),
                      trailing: const Icon(TablerRegular.chevron_right),
                      onTap: onOpenHarnesses,
                    ),
                  ],
                ),
                if (additionalSettings != null) ...[
                  const SizedBox(height: PregoSpacing.xl),
                  additionalSettings,
                ],
                const SizedBox(height: PregoSpacing.xl),
                const BridgeSettingsSection(),
                const SizedBox(height: PregoSpacing.xl),
                SettingsSection(
                  title: loc.settingsDefaultInputTitle,
                  child: const ChatInputModePicker(),
                ),
                const SizedBox(height: PregoSpacing.xl),
                SettingsSection(
                  title: loc.settingsSectionAppearance,
                  child: const AppearancePicker(),
                ),
                const SizedBox(height: PregoSpacing.xl),
                SettingsSection(
                  title: loc.settingsSectionSupport,
                  child: PregoGroupedRows(
                    children: [
                      _SupportRow(
                        icon: TablerRegular.mail,
                        title: loc.settingsSupportEmail,
                        url: SupportLinks.email,
                        openSupportLink: openSupportLink,
                      ),
                      _SupportRow(
                        icon: TablerRegular.brand_discord,
                        title: loc.settingsSupportDiscord,
                        url: SupportLinks.discord,
                        openSupportLink: openSupportLink,
                      ),
                      _SupportRow(
                        // Tabler's pinned set ships the legacy bird glyph,
                        // not the X mark.
                        icon: TablerRegular.brand_twitter,
                        title: loc.settingsSupportX,
                        url: SupportLinks.x,
                        openSupportLink: openSupportLink,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PregoSpacing.xl),
                SettingsSection(
                  title: loc.settingsSectionLegal,
                  child: PregoGroupedRows(
                    children: [
                      _LegalRow(
                        icon: TablerRegular.file_text,
                        title: loc.settingsLegalTerms,
                        document: LegalDocument.terms,
                        openLegalDocument: openLegalDocument,
                      ),
                      _LegalRow(
                        icon: TablerRegular.lock,
                        title: loc.settingsLegalPrivacy,
                        document: LegalDocument.privacy,
                        openLegalDocument: openLegalDocument,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PregoSpacing.x4l),
                _AppFooter(
                  loadAppVersionInfo: loadAppVersionInfo,
                  logo: footerLogo,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + PregoSpacing.xl),
        ),
      ],
    );
  }
}

/// A support-channel row. The destinations are apps of their own (mail client,
/// Discord, X), so they hand off externally rather than opening in-app.
class const _SupportRow({
  required final IconData icon,
  required final String title,
  required final String url,
  required final Future<void> Function({required Uri url}) openSupportLink,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedRow(
      icon: icon,
      title: Text(title),
      trailing: const Icon(TablerRegular.external_link),
      onTap: () => unawaited(openSupportLink(url: Uri.parse(url))),
    );
  }
}

/// A legal-document row. The shell decides whether to render the markdown
/// in-app or hand the document off to an external browser.
class const _LegalRow({
  required final IconData icon,
  required final String title,
  required final LegalDocument document,
  required final Future<void> Function({required LegalDocument document}) openLegalDocument,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedRow(
      icon: icon,
      title: Text(title),
      trailing: const Icon(TablerRegular.chevron_right),
      onTap: () => unawaited(openLegalDocument(document: document)),
    );
  }
}

/// The Figma footer: an optional shell-owned product mark above the app name
/// and the build line supplied by the shell's package-info strategy.
class const _AppFooter({
  required final Future<AppVersionInfo?> Function() loadAppVersionInfo,
  required final Widget? logo,
}) extends StatefulWidget {
  @override
  State<_AppFooter> createState() => _AppFooterState();
}

class _AppFooterState() extends State<_AppFooter> {
  /// Gap between the product name and the version line.
  static const double _versionGap = PregoSpacing.lg;

  late final Future<AppVersionInfo?> _versionInfo = widget.loadAppVersionInfo();

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final logo = widget.logo;

    return Column(
      children: [
        ?logo,
        Text(
          context.loc.settingsAppName,
          style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textPrimary),
        ),
        FutureBuilder<AppVersionInfo?>(
          future: _versionInfo,
          builder: (context, snapshot) {
            final info = snapshot.data;
            if (info == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsetsDirectional.only(top: _versionGap),
              child: Text(
                context.loc.settingsVersion(info.version, info.buildNumber),
                textAlign: TextAlign.center,
                style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
              ),
            );
          },
        ),
      ],
    );
  }
}
