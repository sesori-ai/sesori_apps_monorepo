/// Build-only release selection, separate from GUI/helper identity.
enum DesktopReleaseChannel() {
  stable,
  internal;

  static const String defineName = "SESORI_DESKTOP_RELEASE_CHANNEL";
}
