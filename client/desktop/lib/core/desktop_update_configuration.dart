import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Shell-owned package/link policy. Malformed build metadata fails closed.
DesktopUpdateDestination resolveDesktopUpdateDestination({
  required String? encodedIdentity,
  required String encodedChannel,
}) {
  final channel = DesktopReleaseChannel.values.byName(encodedChannel);
  final identity = encodedIdentity == null ? null : DesktopBundleIdentity.decode(encoded: encodedIdentity);
  if (identity == null) return const DesktopDevelopmentUpdate();
  if (identity.os == DesktopBundleOs.linux) return const DesktopPackageManagerUpdate();
  return DesktopManualDownload(
    uri: Uri(
      scheme: "https",
      host: "sesori.com",
      path: "/desktop/",
      fragment: "${channel.name}-${identity.os.name}-${identity.architecture.name}",
    ),
  );
}
