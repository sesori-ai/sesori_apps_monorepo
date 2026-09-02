import "package:sesori_shared/sesori_shared.dart";

/// Outcome of a scoped stop, in wire terms.
sealed class const SessionAbortResult();

final class const SessionAborted() extends SessionAbortResult;

/// A `confirm` stop the plugin refused because sub-agents are running.
final class const SessionAbortRejected({required final SessionAbortRejection rejection}) extends SessionAbortResult;
