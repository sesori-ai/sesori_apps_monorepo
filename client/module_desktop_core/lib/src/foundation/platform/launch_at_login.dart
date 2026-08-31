/// Layer-0 capability for registering the desktop application to launch at
/// the current user's next login.
abstract interface class LaunchAtLogin() {
  Future<bool> isEnabled();

  Future<void> enable();

  Future<void> disable();
}
