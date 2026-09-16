import "desktop_bundle_identity.dart";

/// Build-only release selection, separate from GUI/helper identity.
enum DesktopReleaseChannel() {
  stable,
  internal;

  static const String defineName = "SESORI_DESKTOP_RELEASE_CHANNEL";
}

/// Immutable presentation destination; never persisted or exchanged with peers.
sealed class const DesktopUpdateDestination() {
  factory forBundle({required DesktopBundleIdentity? identity, required DesktopReleaseChannel channel}) {
    if (identity == null) return const DesktopDevelopmentUpdate();
    if (identity.os == DesktopBundleOs.linux) return const DesktopPackageManagerUpdate();
    return DesktopManualDownload(
      uri: Uri(
        scheme: "https",
        host: "github.com",
        path: "/sesori-ai/sesori_apps_monorepo/blob/main/docs/desktop/downloads.md",
        fragment: "${channel.name}-${identity.os.name}-${identity.architecture.name}",
      ),
    );
  }
}

final class const DesktopManualDownload({required final Uri uri}) extends DesktopUpdateDestination;

final class const DesktopPackageManagerUpdate() extends DesktopUpdateDestination;

final class const DesktopDevelopmentUpdate() extends DesktopUpdateDestination;
