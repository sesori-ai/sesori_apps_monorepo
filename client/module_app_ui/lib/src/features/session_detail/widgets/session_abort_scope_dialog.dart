import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Stops the session, asking for scope when the bridge refuses a plain stop
/// because sub-agents are still running.
///
/// The first request is a `confirm` probe: with no sub-agents running the
/// bridge performs it as a plain stop, and only a rejection is side-effect
/// free. On rejection the dialog confirms the stop of everything that runs;
/// dismissing it leaves everything running.
Future<void> stopSessionWithScope({required BuildContext context, required SessionDetailCubit cubit}) async {
  // One probe-and-dialog sequence per session at a time: a second tap while the
  // first is in flight would stack a stale dialog over the fresh one.
  if (!_stopping.add(cubit)) return;
  try {
    await _stopSessionWithScope(context: context, cubit: cubit);
  } finally {
    _stopping.remove(cubit);
  }
}

final Set<SessionDetailCubit> _stopping = {};

Future<void> _stopSessionWithScope({required BuildContext context, required SessionDetailCubit cubit}) async {
  final outcome = await cubit.abort(subAgents: SessionAbortSubAgentPolicy.confirm);
  if (!context.mounted) return;
  switch (outcome) {
    case SessionAbortRejected(:final rejection):
      final loc = context.loc;
      final count = rejection.runningSubAgentCount;
      final policy = await showPregoModal<SessionAbortSubAgentPolicy>(
        context: context,
        title: loc.sessionDetailStopScopeTitle,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                rejection.mainAgentRunning
                    ? loc.sessionDetailStopScopeMessage(count)
                    : loc.sessionDetailStopScopeMessageMainIdle(count),
                style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
              ),
              const SizedBox(height: PregoSpacing.x2l),
              PregoButtonsSolid(
                label: rejection.mainAgentRunning
                    ? loc.sessionDetailStopAll(count)
                    : loc.sessionDetailStopSubAgentsOnly(count),
                hierarchy: PregoButtonsSolidHierarchy.primary,
                type: PregoButtonsSolidType.destructive,
                size: PregoButtonsSolidSize.lg,
                fullWidth: true,
                onPressed: () => sheetContext.pop(SessionAbortSubAgentPolicy.stop),
              ),
              if (rejection.mainAgentRunning && rejection.mainAgentOnlySupported) ...[
                const SizedBox(height: PregoSpacing.md),
                PregoButtonsSolid(
                  label: loc.sessionDetailStopMainAgentOnly,
                  hierarchy: PregoButtonsSolidHierarchy.secondary,
                  size: PregoButtonsSolidSize.lg,
                  fullWidth: true,
                  onPressed: () => sheetContext.pop(SessionAbortSubAgentPolicy.keep),
                ),
              ],
              const SizedBox(height: PregoSpacing.md),
              PregoButtonsSolid(
                label: loc.sessionListDeleteConfirmCancel,
                hierarchy: PregoButtonsSolidHierarchy.tertiary,
                size: PregoButtonsSolidSize.lg,
                fullWidth: true,
                onPressed: () => sheetContext.pop(),
              ),
            ],
          ),
        ),
      );
      if (policy != null && context.mounted) {
        final followUpOutcome = await cubit.abort(subAgents: policy);
        if (!context.mounted) return;
        if (followUpOutcome case SessionAbortNotAccepted(:final refusal)) {
          await _showNotAccepted(context: context, refusal: refusal);
        }
      }
    case SessionAbortNotAccepted(:final refusal):
      await _showNotAccepted(context: context, refusal: refusal);
    case SessionAbortAccepted() || SessionAbortFailed():
      break;
  }
}

Future<void> _showNotAccepted({required BuildContext context, required SessionAbortNotPerformedRefusal refusal}) async {
  final message = switch (refusal.reason) {
    SessionAbortRefusalReason.residentWorkCompletionUnknown =>
      context.loc.sessionDetailStopNotAcceptedBackgroundMessage,
    SessionAbortRefusalReason.unknownEnumValue => context.loc.sessionDetailStopNotAcceptedGenericMessage,
  };
  await showPregoModal<void>(
    context: context,
    title: context.loc.sessionDetailStopNotAcceptedTitle,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoButtonsSolid(
            label: context.loc.sessionListDeleteConfirmCancel,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: () => sheetContext.pop(),
          ),
        ],
      ),
    ),
  );
}
