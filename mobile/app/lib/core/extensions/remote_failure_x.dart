import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../l10n/app_localizations.dart";

extension RemoteFailureReasonLocalization on RemoteFailureReason {
  /// Maps this domain failure reason to a localized, user-facing message.
  /// Shared by every feature's error view so the `reason → string` mapping
  /// lives in one place.
  String localizedMessage(AppLocalizations loc) => switch (this) {
    RemoteFailureReason.notAuthenticated => loc.apiErrorNotAuthenticated,
    RemoteFailureReason.serverRejected => loc.apiErrorServerRejected,
    RemoteFailureReason.networkDown => loc.apiErrorNetworkDown,
    RemoteFailureReason.badResponse => loc.connectErrorUnexpectedFormat,
    RemoteFailureReason.unknown => loc.connectErrorUnknown,
  };
}
