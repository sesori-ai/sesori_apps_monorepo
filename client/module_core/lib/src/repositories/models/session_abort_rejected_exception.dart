import "package:sesori_shared/sesori_shared.dart";

/// A `confirm` stop the bridge refused because sub-agents are running.
class const SessionAbortRejectedException({
  required final SessionAbortRejection rejection,
  required final Object innerError,
}) implements Exception;
