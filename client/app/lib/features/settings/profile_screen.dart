import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_banner.dart";
import "widgets/account_row.dart";
import "widgets/settings_section.dart";

/// Vertical inset between the nav bar and the first card.
const double _contentTopPadding = 10.0;

/// The account profile screen, reached from the settings account row.
///
/// Shows the signed-in account card, basic usage analytics preference, and the
/// log-out action. The Figma design adds usage stats, model rankings, and
/// account deletion here — those ship with their features later.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          create: (_) => ProductAnalyticsPreferenceCubit(service: getIt<ProductAnalyticsService>()),
        ),
      ],
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
                  SettingsSection(
                    title: loc.settingsSectionAnalytics,
                    child: const _ProductAnalyticsPreferenceRow(),
                  ),
                  const SizedBox(height: PregoSpacing.xl),
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

class _ProductAnalyticsPreferenceRow extends StatelessWidget {
  const _ProductAnalyticsPreferenceRow();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<ProductAnalyticsPreferenceCubit>().state;
    final preference = state.displayedPreference;
    final isBusy =
        state.synchronization is ProductAnalyticsSynchronizationInProgress ||
        state.synchronization is ProductAnalyticsDisableRequestInProgress ||
        state.synchronization is ProductAnalyticsEnableRequestInProgress;
    final status = switch (state.synchronization) {
      ProductAnalyticsSynchronizationInProgress() || ProductAnalyticsNotSynchronized() => (
        text: loc.settingsBasicUsageAnalyticsLoading,
        isFailure: false,
      ),
      ProductAnalyticsDisableRequestInProgress() || ProductAnalyticsEnableRequestInProgress() => (
        text: loc.settingsBasicUsageAnalyticsSaving,
        isFailure: false,
      ),
      ProductAnalyticsDisablePending() || ProductAnalyticsEnablePending() || ProductAnalyticsDisableRetryRequired() => (
        text: loc.settingsBasicUsageAnalyticsSaveFailed,
        isFailure: true,
      ),
      ProductAnalyticsSynchronizationFailed() => (
        text: preference == null
            ? loc.settingsBasicUsageAnalyticsLoadFailed
            : loc.settingsBasicUsageAnalyticsSaveFailed,
        isFailure: true,
      ),
      ProductAnalyticsSynchronized() => null,
    };
    final hasFailure = status?.isFailure ?? false;
    final canToggle = preference != null && !isBusy && !hasFailure;

    void toggle({required bool enabled}) {
      unawaited(context.read<ProductAnalyticsPreferenceCubit>().setEnabled(enabled: enabled));
    }

    final row = PregoGroupedRow(
      icon: TablerRegular.chart_bar,
      title: Text(loc.settingsBasicUsageAnalyticsTitle),
      subtitle: _ProductAnalyticsPreferenceSubtitle(
        status: status?.text,
        statusIsFailure: hasFailure,
      ),
      trailing: hasFailure
          ? PregoButtonsSolid(
              key: const Key("analytics_preference_retry"),
              label: loc.settingsBasicUsageAnalyticsRetry,
              hierarchy: PregoButtonsSolidHierarchy.link,
              size: PregoButtonsSolidSize.sm,
              leadingIcon: TablerRegular.refresh,
              onPressed: () => unawaited(context.read<ProductAnalyticsPreferenceCubit>().refresh()),
            )
          : PregoSwitch(
              value: preference == ProductAnalyticsPreference.enabled,
              onChanged: canToggle ? (enabled) => toggle(enabled: enabled) : null,
            ),
      onTap: canToggle ? () => toggle(enabled: preference != ProductAnalyticsPreference.enabled) : null,
      isLast: true,
    );
    return PregoGroupedRows(
      children: [hasFailure ? row : MergeSemantics(child: row)],
    );
  }
}

class _ProductAnalyticsPreferenceSubtitle extends StatelessWidget {
  const _ProductAnalyticsPreferenceSubtitle({
    required this.status,
    required this.statusIsFailure,
  });

  final String? status;
  final bool statusIsFailure;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.loc.settingsBasicUsageAnalyticsDescription),
        if (status != null) ...[
          const SizedBox(height: PregoSpacing.xs),
          Text(
            status,
            style: statusIsFailure
                ? context.prego.textTheme.textXs.medium.copyWith(
                    color: context.prego.colors.textErrorPrimary,
                  )
                : null,
          ),
        ],
      ],
    );
  }
}
