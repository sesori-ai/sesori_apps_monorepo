import "desktop_bundle_identity.dart";

/// How this desktop build was installed, which decides the update engine.
enum DesktopInstallKind() {
  macosSparkle,
  velopack,
  linuxPackage,
  development;

  /// Source builds carry no compiled identity. A Linux build outside an
  /// AppImage was installed by a DEB or RPM package.
  static DesktopInstallKind resolve({required DesktopBundleIdentity? compiledIdentity, required bool isAppImage}) =>
      switch (compiledIdentity?.os) {
        null => development,
        DesktopBundleOs.macos => macosSparkle,
        DesktopBundleOs.windows => velopack,
        DesktopBundleOs.linux => isAppImage ? velopack : linuxPackage,
      };
}
