import "package:sesori_shared/sesori_shared.dart";

/// Outcome of a scoped stop, in wire terms.
sealed class const SessionAbortResult();

/// The stop was performed; [workKept] says resident work was left running.
/// [subAgentsHandled] prevents a client from repeating plugin-owned fanout;
/// [handledSubAgentSessionIds] narrows any remaining fanout to unhandled work.
final class const SessionAborted({
  required final bool workKept,
  required final bool subAgentsHandled,
  required final List<String> handledSubAgentSessionIds,
}) extends SessionAbortResult;

/// A `confirm` stop the plugin refused because sub-agents are running.
final class const SessionAbortRejected({required final SessionAbortRejection rejection}) extends SessionAbortResult;
