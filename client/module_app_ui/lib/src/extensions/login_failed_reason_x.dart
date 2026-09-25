import "package:sesori_dart_core/sesori_dart_core.dart";

import "../l10n/app_localizations.dart";

extension LoginFailedReasonLocalization on LoginFailedReason {
  /// Maps this login failure reason to a localized, user-facing message.
  /// Shared by every shell's login failure surface and the email sign-in
  /// form's inline alert so the `reason → string` mapping lives in one place.
  String localizedMessage(AppLocalizations loc) => switch (this) {
    LoginFailedReason.declined => loc.loginDeclined,
    LoginFailedReason.appleIdTokenMissing => loc.appleIdTokenMissing,
    LoginFailedReason.emailRequired => loc.emailRequired,
    LoginFailedReason.passwordRequired => loc.passwordRequired,
    LoginFailedReason.unknown => loc.loginError,
  };
}
