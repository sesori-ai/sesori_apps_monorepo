import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../utils/copy_text_to_clipboard.dart";
import "../../widgets/bridge_update_sheet.dart";
import "widgets/settings_section.dart";
import "widgets/settings_window_page.dart";

part "harness_settings_sheets.dart";
part "harness_settings_presentation.dart";
part "harness_settings_detail_view.dart";
part "harnesses_settings_view.dart";

/// Who draws the harness pages' chrome: their own bar, closed as a modal or
/// left by going back, or the desktop settings window, which owns the close
/// button while the pages keep their way back.
enum HarnessSettingsChrome() { modal, pushed, window }

/// Owns transient presentation once for the entire nested harness navigator.
class const HarnessSettingsFlowView({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PluginManagementCubit>();
    final state = context.watch<PluginManagementCubit>().state;
    return _HarnessPresentationScope(
      presentationContext: context,
      child: MultiBlocListener(
        listeners: [
          if (state is PluginManagementReady)
            for (final plugin in state.response.plugins)
              BlocListener<PluginManagementCubit, PluginManagementState>(
                key: ValueKey(plugin.setup.id),
                listenWhen: (previous, current) =>
                    current is PluginManagementReady &&
                    current.harnessActions[plugin.setup.id] is PluginManagementActionForceConfirmationRequired &&
                    (previous is! PluginManagementReady ||
                        !identical(previous.harnessActions[plugin.setup.id], current.harnessActions[plugin.setup.id])),
                listener: (context, state) {
                  if (state is! PluginManagementReady) return;
                  final confirmation = state.harnessActions[plugin.setup.id];
                  if (confirmation is! PluginManagementActionForceConfirmationRequired) return;
                  // A covered flow does not stack dialogs. Its retained result
                  // is reachable through the harness' explicit Review action.
                  unawaited(_showForceConfirmation(context: context, cubit: cubit, confirmation: confirmation));
                },
              ),
          BlocListener<PluginManagementCubit, PluginManagementState>(
            listenWhen: (previous, current) {
              final prior = _authenticationChallenge(state: previous);
              final next = _authenticationChallenge(state: current);
              return next != null &&
                  (prior == null ||
                      next is PluginAuthenticationPresentationStarting &&
                          (prior is PluginAuthenticationPresentationSucceeded ||
                              prior is PluginAuthenticationPresentationCancelled ||
                              prior is PluginAuthenticationPresentationFailed));
            },
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

PluginAuthenticationPresentationState? _authenticationChallenge({
  required PluginManagementState state,
}) => switch (state) {
  PluginManagementReady(:final authentication)
      when authentication is! PluginAuthenticationPresentationIdle &&
          (authentication is! PluginAuthenticationPresentationFailed || authentication.pluginId != null) =>
    authentication,
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
