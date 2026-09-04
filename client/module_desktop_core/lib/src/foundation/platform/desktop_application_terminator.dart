/// Layer-0 capability that terminates the desktop process after business
/// teardown has completed.
abstract interface class DesktopApplicationTerminator() {
  void terminate({required int exitCode});
}
