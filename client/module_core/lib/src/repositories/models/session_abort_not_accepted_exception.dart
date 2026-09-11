import "package:sesori_shared/sesori_shared.dart";

/// A typed refusal proving the bridge performed no abort side effect.
class const SessionAbortNotAcceptedException({
  required final SessionAbortRefusal refusal,
  required final Object innerError,
}) implements Exception;
