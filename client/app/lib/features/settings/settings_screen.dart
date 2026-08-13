import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/external_link.dart";
import "../../core/routing/app_router.dart";
import "../../core/support_links.dart";
import "../../core/widgets/connection_banner.dart";
import "../../core/widgets/legal_document_sheet.dart";
import "../../core/widgets/sesori_logo.dart";
import "widgets/account_row.dart";
import "widgets/appearance_picker.dart";
import "widgets/bridge_settings_section.dart";
import "widgets/chat_input_mode_picker.dart";
import "widgets/settings_section.dart";

/// Vertical inset between the nav bar and the first settings section.
const double _contentTopPadding = 10.0;

/// The settings landing screen, presented as a full-screen modal.
///
/// Shows the signed-in account (navigating to the profile screen), a
/// notifications row (navigating to notification preferences), and the app
/// version footer.
class const SettingsScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => SettingsCubit(
            authSession: getIt<AuthSession>(),
            notificationRegistrationService: getIt<NotificationRegistrationService>(),
            productAnalyticsService: getIt<ProductAnalyticsService>(),
          ),
        ),
        BlocProvider(
          create: (_) => BridgeSettingsCubit(
            service: getIt<BridgeSettingsService>(),
            connectionService: getIt<ConnectionService>(),
          ),
        ),
      ],
      child: const _SettingsBody(),
    );
  }
}

class const _SettingsBody() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final account = context.watch<SettingsCubit>().state.account;

    return PregoGlassScaffold(
      title: loc.settingsTitle,
      banner: ConnectionBanner.maybeFor(context),
      onRefresh: () async {
        await context.read<BridgeSettingsCubit>().refresh();
      },
      automaticallyImplyLeading: false,
      actions: [
        PregoButtonsIconGlass(
          icon: TablerRegular.x,
          semanticLabel: loc.settingsClose,
          onPressed: () => context.pop(),
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
                        AccountRow(
                          account: account,
                          onTap: () => context.pushRoute(const AppRoute.settingsProfile()),
                        )
                      else
                        PregoGroupedRow(
                          leading: const PregoAvatarUser(),
                          title: Text(loc.settingsProfileTitle),
                          trailing: const Icon(TablerRegular.chevron_right),
                          onTap: () => context.pushRoute(const AppRoute.settingsProfile()),
                          isLast: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: PregoSpacing.xl),
                PregoGroupedRows(
                  children: [
                    PregoGroupedRow(
                      icon: TablerRegular.bell,
                      title: Text(loc.settingsNotificationsTitle),
                      trailing: const Icon(TablerRegular.chevron_right),
                      onTap: () => context.pushRoute(const AppRoute.settingsNotifications()),
                    ),
                    PregoGroupedRow(
                      icon: TablerRegular.plug,
                      title: Text(loc.settingsHarnessesTitle),
                      trailing: const Icon(TablerRegular.chevron_right),
                      onTap: () => context.pushRoute(
                        const AppRoute.settingsHarnesses(
                          presentation: HarnessSettingsPresentation.pushed,
                        ),
                      ),
                      isLast: true,
                    ),
                  ],
                ),
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
                      ),
                      _SupportRow(
                        icon: TablerRegular.brand_discord,
                        title: loc.settingsSupportDiscord,
                        url: SupportLinks.discord,
                      ),
                      _SupportRow(
                        // Tabler's pinned set ships the legacy bird glyph,
                        // not the X mark.
                        icon: TablerRegular.brand_twitter,
                        title: loc.settingsSupportX,
                        url: SupportLinks.x,
                        isLast: true,
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
                      ),
                      _LegalRow(
                        icon: TablerRegular.lock,
                        title: loc.settingsLegalPrivacy,
                        document: LegalDocument.privacy,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PregoSpacing.x4l),
                const _AppFooter(),
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
  final bool isLast = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedRow(
      icon: icon,
      title: Text(title),
      trailing: const Icon(TablerRegular.external_link),
      onTap: () => unawaited(
        openExternalLink(url: Uri.parse(url), mode: UrlLaunchMode.externalApp).then<void>((_) {}),
      ),
      isLast: isLast,
    );
  }
}

/// A legal-document row. The backend serves these documents as markdown, so
/// they open in a bottom sheet instead of handing off to a web page.
class const _LegalRow({
  required final IconData icon,
  required final String title,
  required final LegalDocument document,
  final bool isLast = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedRow(
      icon: icon,
      title: Text(title),
      trailing: const Icon(TablerRegular.chevron_right),
      onTap: () => unawaited(showLegalDocumentSheet(context, document: document)),
      isLast: isLast,
    );
  }
}

/// The Figma footer: the app icon above the product name and the
/// "v1.2.3 (456)" build line sourced from the platform package info.
class const _AppFooter() extends StatelessWidget {
  /// Edge length of the icon's rounded square, per Figma.
  static const double _logoSquare = 52.0;

  /// Gap between the product name and the version line.
  static const double _versionGap = PregoSpacing.lg;

  static final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Column(
      children: [
        // The logo's own frame reserves the space its drop shadow needs, which
        // doubles as the gap down to the name — as on the login screen.
        const SesoriLogo(squareSize: _logoSquare),
        Text(
          context.loc.settingsAppName,
          style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textPrimary),
        ),
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
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
