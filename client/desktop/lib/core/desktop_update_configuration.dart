import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Parse build configuration outside presentation; malformed metadata fails closed.
DesktopUpdateDestination resolveDesktopUpdateDestination({
  required String? encodedIdentity,
  required String encodedChannel,
}) => DesktopUpdateDestination.forBundle(
  identity: encodedIdentity == null ? null : DesktopBundleIdentity.decode(encoded: encodedIdentity),
  channel: DesktopReleaseChannel.values.byName(encodedChannel),
);
