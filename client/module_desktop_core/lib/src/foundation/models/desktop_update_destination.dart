/// Build-only release selection, separate from GUI/helper identity.
enum DesktopReleaseChannel() {
  stable,
  internal;

  static const String defineName = "SESORI_DESKTOP_RELEASE_CHANNEL";
}

/// Immutable presentation destination; never persisted or exchanged with peers.
sealed class const DesktopUpdateDestination();

final class const DesktopManualDownload({required final Uri uri}) extends DesktopUpdateDestination;

final class const DesktopPackageManagerUpdate() extends DesktopUpdateDestination;

final class const DesktopDevelopmentUpdate() extends DesktopUpdateDestination;
