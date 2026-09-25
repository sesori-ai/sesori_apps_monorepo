/// What the user needs to finish a started browser sign-in: the page to open,
/// when the pending session expires, and the device name that page asks them
/// to confirm.
final class const OAuthHandoff({
  required final Uri authUrl,
  required final DateTime expiresAt,
  required final String deviceName,
});
