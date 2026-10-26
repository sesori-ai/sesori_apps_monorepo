/// Layer-0 capability that terminates the desktop process after business
/// teardown has completed.
abstract interface class DesktopApplicationTerminator() {
  /// Ends the process. On macOS this answers a pending system quit request,
  /// or asks AppKit to terminate, so the app exits normally.
  void terminate();

  /// The quit failed and the app keeps running: declines a pending system
  /// quit request. Hosts without one ignore it.
  void cancelTermination();
}
