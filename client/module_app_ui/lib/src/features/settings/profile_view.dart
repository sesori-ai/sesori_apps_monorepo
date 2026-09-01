import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "widgets/account_row.dart";
import "widgets/settings_section.dart";

/// Vertical inset between the nav bar and the first card.
const double _contentTopPadding = 10.0;

/// Shared account profile view.
///
/// The product shell injects the complete logout workflow. Mobile preserves
/// its notification/analytics cleanup through `SettingsCubit.logout`, while
/// desktop supplies its supervised-helper-aware logout orchestrator.
class const ProfileView({
  super.key,
  required final AuthUser? account,
  required final Widget? connectionBanner,
  required final VoidCallback onClose,
  required final Future<bool> Function() logout,
}) extends StatefulWidget {
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState() extends State<ProfileView> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    final bool succeeded;
    try {
      succeeded = await widget.logout();
    } on Object catch (error, stackTrace) {
      loge("Settings logout strategy failed", error, stackTrace);
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      _showLogoutFailure();
      return;
    }

    if (!mounted) return;
    setState(() => _isLoggingOut = false);
    if (!succeeded) _showLogoutFailure();
  }

  void _showLogoutFailure() {
    PregoPopupAlertPresenter.of(context).show(
      title: context.loc.connectErrorUnknown,
      variant: PregoPopupAlertsNotificationsVariant.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final account = widget.account;

    return PregoGlassScaffold(
      title: loc.settingsProfileTitle,
      titleMode: PregoTopNavigationTitleMode.inline,
      banner: widget.connectionBanner,
      actions: [
        PregoButtonsIconGlass(
          icon: TablerRegular.x,
          semanticLabel: loc.settingsClose,
          onPressed: widget.onClose,
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
                  child: _ProductAnalyticsPreferenceRow(blocked: _isLoggingOut),
                ),
                const SizedBox(height: PregoSpacing.xl),
                PregoGroupedRows(
                  children: [
                    PregoGroupedRow(
                      icon: TablerRegular.logout,
                      title: Text(loc.settingsLogout),
                      trailing: _isLoggingOut
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
                            )
                          : null,
                      onTap: _isLoggingOut ? null : () => unawaited(_logout()),
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
    );
  }
}

class const _ProductAnalyticsPreferenceRow({required final bool blocked}) extends StatelessWidget {
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
        text: loc.settingsBasicUsageAnalyticsSyncFailed,
        isFailure: true,
      ),
      ProductAnalyticsSynchronizationFailed() => (
        text: preference == null
            ? loc.settingsBasicUsageAnalyticsLoadFailed
            : loc.settingsBasicUsageAnalyticsSyncFailed,
        isFailure: true,
      ),
      ProductAnalyticsSynchronized() => null,
    };
    final hasFailure = status?.isFailure ?? false;
    final canToggle = preference != null && !isBusy && !blocked;

    void toggle({required bool enabled}) {
      unawaited(context.read<ProductAnalyticsPreferenceCubit>().setEnabled(enabled: enabled));
    }

    final preferenceSwitch = PregoSwitch(
      value: preference == ProductAnalyticsPreference.enabled,
      onChanged: canToggle ? (enabled) => toggle(enabled: enabled) : null,
    );
    final retryButton = Semantics(
      label: loc.settingsBasicUsageAnalyticsRetry,
      child: PregoButtonsSolid.iconOnly(
        key: const Key("analytics_preference_retry"),
        hierarchy: PregoButtonsSolidHierarchy.link,
        size: PregoButtonsSolidSize.sm,
        leadingIcon: TablerRegular.refresh,
        onPressed: blocked ? null : () => unawaited(context.read<ProductAnalyticsPreferenceCubit>().refresh()),
      ),
    );
    final Widget trailing;
    if (!hasFailure) {
      trailing = preferenceSwitch;
    } else if (preference == null) {
      trailing = retryButton;
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: PregoSpacing.xs,
        children: [retryButton, preferenceSwitch],
      );
    }

    final row = PregoGroupedRow(
      icon: TablerRegular.chart_bar,
      title: Text(loc.settingsBasicUsageAnalyticsTitle),
      subtitle: _ProductAnalyticsPreferenceSubtitle(
        status: status?.text,
        statusIsFailure: hasFailure,
      ),
      trailing: trailing,
      onTap: canToggle ? () => toggle(enabled: preference != ProductAnalyticsPreference.enabled) : null,
    );
    return PregoGroupedRows(
      children: [hasFailure ? row : MergeSemantics(child: row)],
    );
  }
}

class const _ProductAnalyticsPreferenceSubtitle({
  required final String? status,
  required final bool statusIsFailure,
}) extends StatelessWidget {
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
