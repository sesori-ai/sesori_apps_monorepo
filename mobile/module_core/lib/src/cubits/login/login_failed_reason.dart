/// Typed reasons for a failed login attempt, used by [LoginState.failed]
/// so the UI can perform an exhaustive switch for localized messages.
enum LoginFailedReason {
  browserOpenFailed,
  emailRequired,
  passwordRequired,
  appleIdTokenMissing,
  unknown,
}
