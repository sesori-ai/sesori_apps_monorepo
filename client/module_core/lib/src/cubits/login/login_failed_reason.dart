/// Typed reasons for a failed login attempt, used by [LoginState.failed]
/// so the UI can perform an exhaustive switch for localized messages.
enum LoginFailedReason() {
  /// The user declined the sign-in in the browser.
  declined,
  emailRequired,
  passwordRequired,
  appleIdTokenMissing,
  unknown,
}
