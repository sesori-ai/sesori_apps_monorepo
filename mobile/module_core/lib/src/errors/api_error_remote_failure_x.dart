import "package:sesori_auth/sesori_auth.dart";

import "remote_failure_reason.dart";

export "remote_failure_reason.dart";

/// Maps a transport-level [ApiError] (owned by `sesori_auth`) to the domain
/// [RemoteFailureReason]. Applied at each cubit's error boundary so the
/// transport type never reaches domain state or presentation.
///
/// This is the single source of truth for the `ApiError → reason` translation,
/// shared by every feature that surfaces a [RemoteFailureReason]. Importing this
/// file does not leak `sesori_auth` into the importer (Dart imports are not
/// transitive); the re-export only surfaces [RemoteFailureReason].
extension ApiErrorRemoteFailure on ApiError {
  RemoteFailureReason get remoteFailureReason => switch (this) {
    NotAuthenticatedError() => RemoteFailureReason.notAuthenticated,
    NonSuccessCodeError() => RemoteFailureReason.serverRejected,
    DartHttpClientError() => RemoteFailureReason.networkDown,
    JsonParsingError() || EmptyResponseError() => RemoteFailureReason.badResponse,
    GenericError() => RemoteFailureReason.unknown,
  };
}
