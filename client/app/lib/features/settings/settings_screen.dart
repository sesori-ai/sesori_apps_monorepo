import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_banner.dart";
import "widgets/account_row.dart";
import "widgets/settings_section.dart";

/// Vertical inset between the nav bar and the first settings section.
const double _contentTopPadding = 10.0;

/// The settings landing screen, presented as a full-screen modal.
///
/// Shows the signed-in account (navigating to the profile screen), a
/// notifications row (navigating to notification preferences), and the app
/// version footer.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsCubit(authSession: getIt<AuthSession>()),
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final account = context.watch<SettingsCubit>().state.account;

    return PregoGlassScaffold(
      title: loc.settingsTitle,
      banner: ConnectionBanner.maybeFor(context),
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
                if (account != null) ...[
                  SettingsSection(
                    title: loc.settingsSectionAccount,
                    child: PregoGroupedRows(
                      children: [
                        AccountRow(
                          account: account,
                          onTap: () => context.pushRoute(const AppRoute.settingsProfile()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: PregoSpacing.xl),
                ],
                PregoGroupedRows(
                  children: [
                    PregoGroupedRow(
                      icon: TablerRegular.bell,
                      title: Text(loc.settingsNotificationsTitle),
                      trailing: const Icon(TablerRegular.chevron_right),
                      onTap: () => context.pushRoute(const AppRoute.settingsNotifications()),
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: PregoSpacing.xl),
                const _VersionFooter(),
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

/// Centred "v1.2.3 (456)" footer sourced from the platform package info.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  static final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        return Text(
          context.loc.settingsVersion(info.version, info.buildNumber),
          textAlign: TextAlign.center,
          style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
        );
      },
    );
  }
}
