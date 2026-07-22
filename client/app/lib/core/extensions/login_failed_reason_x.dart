import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../l10n/app_localizations.dart";

extension LoginFailedReasonLocalization on LoginFailedReason {
  /// Maps this login failure reason to a localized, user-facing message.
  /// Shared by the login screen's error banner and the email sign-in sheet's
  /// inline alert so the `reason → string` mapping lives in one place.
  String localizedMessage(AppLocalizations loc) => switch (this) {
    LoginFailedReason.browserOpenFailed => loc.loginBrowserOpenFailed,
    LoginFailedReason.appleIdTokenMissing => loc.appleIdTokenMissing,
    LoginFailedReason.emailRequired => loc.emailRequired,
    LoginFailedReason.passwordRequired => loc.passwordRequired,
    LoginFailedReason.unknown => loc.loginError,
  };
}
