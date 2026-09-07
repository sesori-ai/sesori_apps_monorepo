import "package:sesori_shared/sesori_shared.dart";

/// Outcome of a scoped stop, in wire terms.
sealed class const SessionAbortResult();

/// The stop was performed; [workKept] says resident work was left running.
/// [subAgentsHandled] prevents a client from repeating plugin-owned fanout;
/// [handledSubAgentSessionIds] excludes covered work from legacy fanout;
/// [unhandledSubAgentSessionIds] identifies exact remaining fanout targets.
final class const SessionAborted({
  required final bool workKept,
  required final bool subAgentsHandled,
  required final List<String> handledSubAgentSessionIds,
  required final List<String> unhandledSubAgentSessionIds,
}) extends SessionAbortResult;

/// A `confirm` stop the plugin refused because sub-agents are running.
final class const SessionAbortRejected({required final SessionAbortRejection rejection}) extends SessionAbortResult;
