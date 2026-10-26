/// Whether the app waits on this computer's bridge while the desktop launches it.
enum LocalBridgeStartupState() {
  /// The desktop is launching this computer's bridge, the app views this
  /// computer and has not reached it yet: an offline bridge is still loading.
  starting,

  /// Nothing is launching for the computer the app views, so an offline bridge
  /// shows as offline.
  settled,
}
