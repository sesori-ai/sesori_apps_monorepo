import "package:sesori_shared/sesori_shared.dart";

/// Outcome of a scoped stop in the bridge domain.
sealed class const SessionAbortResult();

/// The stop was performed; [workKept] says resident work was left running.
final class const SessionAborted({
  required final bool workKept,
  required final SessionAbortSubAgentCoverage subAgentCoverage,
}) extends SessionAbortResult;

/// Which descendant stops remain for the client after plugin handling.
sealed class const SessionAbortSubAgentCoverage();

/// The plugin handled every known descendant and any delayed announcements.
final class const SessionAbortSubAgentsHandled() extends SessionAbortSubAgentCoverage;

/// Some exact descendants remain outside plugin/native stop authority.
///
/// [handledSessionIds] is derived from the complete known set, so an id cannot
/// be both handled and unhandled in the serialized response.
final class const SessionAbortSubAgentsPartiallyHandled({
  required final List<String> knownSessionIds,
  required final List<String> unhandledSessionIds,
}) extends SessionAbortSubAgentCoverage {
  List<String> get handledSessionIds {
    final unhandled = unhandledSessionIds.toSet();
    return knownSessionIds.toSet().difference(unhandled).toList(growable: false);
  }
}

/// The plugin cannot report authoritative descendant coverage.
///
/// [handledSessionIds] still protects known covered work from duplicate legacy
/// fanout while the client falls back to visible busy descendants.
final class const SessionAbortSubAgentsLegacyFanout({
  required final List<String> handledSessionIds,
}) extends SessionAbortSubAgentCoverage;

/// A `confirm` stop the plugin refused because sub-agents are running.
final class const SessionAbortRejected({required final SessionAbortRejection rejection}) extends SessionAbortResult;
