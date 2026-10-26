/// Desktop-owned preference for background update checks.
enum DesktopAutomaticUpdates({required final bool isEnabled}) {
  enabled(isEnabled: true),
  disabled(isEnabled: false),
}
