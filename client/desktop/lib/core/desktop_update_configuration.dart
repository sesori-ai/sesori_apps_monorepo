import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Shell-owned package/link policy. Malformed build metadata fails closed.
DesktopUpdateDestination resolveDesktopUpdateDestination({
  required String? encodedIdentity,
  required String encodedChannel,
  required bool isAppImage,
}) {
  final channel = DesktopReleaseChannel.values.byName(encodedChannel);
  final identity = encodedIdentity == null ? null : DesktopBundleIdentity.decode(encoded: encodedIdentity);
  if (identity == null) return const DesktopDevelopmentUpdate();
  final section = "${channel.name}-${identity.os.name}-${identity.architecture.name}";
  // A portable AppImage has no package manager; it is replaced by downloading the new image.
  if (identity.os == DesktopBundleOs.linux && !isAppImage) return const DesktopPackageManagerUpdate();
  return DesktopManualDownload(
    uri: Uri(
      scheme: "https",
      host: "sesori.com",
      path: "/desktop/",
      fragment: isAppImage ? "$section-appimage" : section,
    ),
  );
}
