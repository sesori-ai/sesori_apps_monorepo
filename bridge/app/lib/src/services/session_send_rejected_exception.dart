import "package:sesori_shared/sesori_shared.dart" show SendToSessionErrorCode;

/// A session send that did not reach the target, for the reason [code].
class const SessionSendRejectedException({
  required final SendToSessionErrorCode code,

  /// The harness's explanation for refusing the target prompt, written for
  /// the user. Null for every other failure.
  required final String? userFacingReason,

  /// The failure behind [code], when one caused it.
  required final Object? cause,
  required final StackTrace? causeStackTrace,
}) implements Exception {
  @override
  String toString() => "SessionSendRejectedException(${code.name})";
}
