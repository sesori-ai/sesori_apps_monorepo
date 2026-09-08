import "dart:async";

import "package:flutter/semantics.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../utils/copy_text_to_clipboard.dart";
import "../../widgets/catalog_scan_row.dart";
import "widgets/settings_section.dart";

part "harness_settings_sheets.dart";
part "harness_settings_presentation.dart";
part "harness_settings_detail_view.dart";
part "harnesses_settings_view.dart";

/// Owns transient presentation once for the entire nested harness navigator.
class const HarnessSettingsFlowView({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PluginManagementCubit>();
    return _HarnessPresentationScope(
      presentationContext: context,
      child: MultiBlocListener(
        listeners: [
          BlocListener<PluginManagementCubit, PluginManagementState>(
            listenWhen: (previous, current) => _forceConfirmation(previous) != _forceConfirmation(current),
            listener: (context, state) {
              final confirmation = _forceConfirmation(state);
              if (confirmation == null || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
              unawaited(_showForceConfirmation(context: context, cubit: cubit, confirmation: confirmation));
            },
          ),
          // This screen hosts no progress row, so a scan started here would
          // otherwise end in silence: the spinner stops and the service clears
          // its result before the user could reach a list to read it.
          BlocListener<PluginManagementCubit, PluginManagementState>(
            listenWhen: (previous, current) => _scanOutcome(previous) == null && _scanOutcome(current) != null,
            listener: (context, state) {
              final outcome = _scanOutcome(state);
              if (outcome == null) return;
              final loc = context.loc;
              final (title, variant) = switch (outcome) {
                CatalogRescanOutcomeSucceeded(:final counts) => (
                  loc.harnessManagementScanFinished(catalogScanCountsLine(loc: loc, counts: counts)),
                  PregoPopupAlertsNotificationsVariant.success,
                ),
                CatalogRescanOutcomePartlyFailed(:final succeededCount, :final failedCount) => (
                  loc.harnessManagementScanPartlyFailed(failedCount, succeededCount + failedCount),
                  PregoPopupAlertsNotificationsVariant.error,
                ),
                CatalogRescanOutcomeFailed() => (
                  loc.harnessManagementScanFinishedFailed,
                  PregoPopupAlertsNotificationsVariant.error,
                ),
              };
              PregoPopupAlertPresenter.of(context).show(title: title, variant: variant);
              // Announced as well as shown. The popup renders ordinary text into
              // an overlay, which moves no semantic focus and carries no live
              // region, so on its own it tells a screen-reader user nothing —
              // and they are the reason this surface exists, the pull being a
              // gesture they cannot perform.
              unawaited(
                SemanticsService.sendAnnouncement(View.of(context), title, Directionality.of(context)),
              );
              cubit.dismissCatalogScanOutcome();
            },
          ),
          BlocListener<PluginManagementCubit, PluginManagementState>(
            listenWhen: (previous, current) =>
                _authenticationChallenge(state: previous) == null && _authenticationChallenge(state: current) != null,
            listener: (context, state) {
              final challenge = _authenticationChallenge(state: state);
              if (challenge == null || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
              unawaited(_showAuthenticationSheet(context: context, cubit: cubit));
            },
          ),
        ],
        child: child,
      ),
    );
  }
}

PluginAuthenticationPresentationState? _authenticationChallenge({required PluginManagementState state}) =>
    switch (state) {
      PluginManagementReady(authentication: final PluginAuthenticationPresentationChallenge challenge) => challenge,
      PluginManagementReady(authentication: final PluginAuthenticationPresentationBrowserLaunchFailedState challenge) =>
        challenge,
      PluginManagementReady(authentication: final PluginAuthenticationPresentationCancelling challenge) => challenge,
      PluginManagementReady(authentication: final PluginAuthenticationPresentationCancellingUncertain challenge) =>
        challenge,
      PluginManagementReady() ||
      PluginManagementLoading() ||
      PluginManagementUnsupported() ||
      PluginManagementFailure() => null,
    };

CatalogRescanOutcome? _scanOutcome(PluginManagementState state) => switch (state) {
  PluginManagementReady(:final scanOutcome) => scanOutcome,
  PluginManagementLoading() || PluginManagementUnsupported() || PluginManagementFailure() => null,
};

PluginManagementActionForceConfirmationRequired? _forceConfirmation(PluginManagementState state) => switch (state) {
  PluginManagementReady(action: final PluginManagementActionForceConfirmationRequired confirmation) => confirmation,
  PluginManagementReady() ||
  PluginManagementLoading() ||
  PluginManagementUnsupported() ||
  PluginManagementFailure() => null,
};

// Sheets belong to the stable outer flow page, not an offstage overview or a
// disposable detail page. Navigator removes them when the flow leaves.
BuildContext _flowPresentationContext({required BuildContext context}) =>
    context.getInheritedWidgetOfExactType<_HarnessPresentationScope>()?.presentationContext ??
    (throw StateError("Harness sheets require a harness flow owner"));

class const _HarnessPresentationScope({required final BuildContext presentationContext, required super.child})
    extends InheritedWidget {
  @override
  bool updateShouldNotify(_HarnessPresentationScope oldWidget) => presentationContext != oldWidget.presentationContext;
}
