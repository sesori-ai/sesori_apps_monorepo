import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// Stops the session, asking for scope when the bridge refuses a plain stop
/// because sub-agents are still running.
///
/// The first request is a `confirm` probe: with no sub-agents running the
/// bridge performs it as a plain stop, and only a rejection is side-effect
/// free. On rejection the dialog offers "main agent only" (only while the main
/// agent runs) and "stop everything"; dismissing it leaves everything running.
Future<void> stopSessionWithScope({required BuildContext context, required SessionDetailCubit cubit}) async {
  final outcome = await cubit.abort(subAgents: SessionAbortSubAgentPolicy.confirm);
  if (outcome case SessionAbortRejected(:final rejection) when context.mounted) {
    final loc = context.loc;
    final count = rejection.runningSubAgentCount;
    final policy = await showDialog<SessionAbortSubAgentPolicy>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.sessionDetailStopScopeTitle),
        content: Text(
          rejection.mainAgentRunning
              ? loc.sessionDetailStopScopeMessage(count)
              : loc.sessionDetailStopScopeMessageMainIdle(count),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: Text(loc.sessionListDeleteConfirmCancel),
          ),
          if (rejection.mainAgentRunning)
            TextButton(
              onPressed: () => dialogContext.pop(SessionAbortSubAgentPolicy.keep),
              child: Text(loc.sessionDetailStopMainAgentOnly),
            ),
          TextButton(
            onPressed: () => dialogContext.pop(SessionAbortSubAgentPolicy.stop),
            child: Text(
              rejection.mainAgentRunning ? loc.sessionDetailStopAll(count) : loc.sessionDetailStopSubAgentsOnly(count),
              style: TextStyle(color: context.prego.colors.fgErrorPrimary),
            ),
          ),
        ],
      ),
    );
    if (policy != null && context.mounted) await cubit.abort(subAgents: policy);
  }
}
