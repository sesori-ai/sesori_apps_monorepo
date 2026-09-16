import "package:sesori_shared/sesori_shared.dart";

/// Outcome of a scoped stop, in wire terms.
sealed class const SessionAbortResult();

/// The stop was performed; [workKept] says resident work was left running.
final class const SessionAborted({
  required final bool workKept,
  required final bool subAgentsHandled,
}) extends SessionAbortResult;

/// A `confirm` stop the plugin refused because sub-agents are running.
final class const SessionAbortRejected({required final SessionAbortRejection rejection}) extends SessionAbortResult;

/// The plugin performed no stop because safety could not be established.
final class const SessionAbortNotPerformed({
  required final SessionAbortNotPerformedRefusal refusal,
}) extends SessionAbortResult;
