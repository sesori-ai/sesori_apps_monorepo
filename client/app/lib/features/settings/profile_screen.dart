import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_banner.dart";
import "widgets/account_row.dart";

/// Vertical inset between the nav bar and the first card.
const double _contentTopPadding = 10.0;

/// The account profile screen, reached from the settings account row.
///
/// Shows the signed-in account card and the log-out action. The Figma design
/// adds usage stats, model rankings, and account deletion here — those ship
/// with their features later.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsCubit(authSession: getIt<AuthSession>()),
      child: const _ProfileBody(),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final settingsState = context.watch<SettingsCubit>().state;
    final account = settingsState.account;
    final isLoggingOut = settingsState.logoutStatus == SettingsLogoutStatus.inProgress;

    return BlocListener<SettingsCubit, SettingsState>(
      // Only react to logout transitions — account updates from the auth
      // stream also emit new states and must not re-trigger navigation.
      listenWhen: (prev, curr) => prev.logoutStatus != curr.logoutStatus,
      listener: (context, settingsState) {
        switch (settingsState.logoutStatus) {
          case SettingsLogoutStatus.success:
            context.goRoute(const AppRoute.splash());
          case SettingsLogoutStatus.failure:
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(content: Text(loc.connectErrorUnknown)));
          case SettingsLogoutStatus.idle:
          case SettingsLogoutStatus.inProgress:
            break;
        }
      },
      child: PregoGlassScaffold(
        title: loc.settingsProfileTitle,
        titleMode: PregoTopNavigationTitleMode.inline,
        banner: ConnectionBanner.maybeFor(context),
        actions: [
          PregoButtonsIconGlass(
            icon: TablerRegular.x,
            semanticLabel: loc.settingsClose,
            onPressed: () => context.goRoute(const AppRoute.projects()),
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
                    PregoGroupedRows(
                      children: [AccountRow(account: account, onTap: null)],
                    ),
                    const SizedBox(height: PregoSpacing.xl),
                  ],
                  PregoGroupedRows(
                    children: [
                      PregoGroupedRow(
                        icon: TablerRegular.logout,
                        title: Text(loc.settingsLogout),
                        trailing: isLoggingOut
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                        onTap: isLoggingOut ? null : () => context.read<SettingsCubit>().logout(),
                        isLast: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + PregoSpacing.xl),
          ),
        ],
      ),
    );
  }
}
