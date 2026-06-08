import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../l10n/app_localizations.dart";

extension ApiErrorLocalization on ApiError {
  /// Maps this error to a localized, user-facing message. Shared by the error
  /// views across the projects, session-list, and session-detail screens.
  String localizedMessage(AppLocalizations loc) => switch (this) {
    NotAuthenticatedError() => loc.apiErrorNotAuthenticated,
    NonSuccessCodeError(:final errorCode, :final rawErrorString) =>
      rawErrorString != null
          ? loc.connectErrorNonSuccessCodeWithBody(errorCode, rawErrorString)
          : loc.connectErrorNonSuccessCode(errorCode),
    DartHttpClientError(:final innerError) => loc.connectErrorConnectionFailed(innerError.toString()),
    JsonParsingError() => loc.connectErrorUnexpectedFormat,
    EmptyResponseError() => loc.connectErrorUnexpectedFormat,
    GenericError() => loc.connectErrorUnknown,
  };
}
