import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/desktop_update_configuration.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

void main() {
  test("source builds have no guessed download destination", () {
    expect(
      resolveDesktopUpdateDestination(encodedIdentity: null, encodedChannel: "stable"),
      isA<DesktopDevelopmentUpdate>(),
    );
  });
  for (final os in DesktopBundleOs.values) {
    for (final architecture in DesktopBundleArchitecture.values) {
      for (final channel in DesktopReleaseChannel.values) {
        test("${channel.name}/${os.name}/${architecture.name} selects its official index section", () {
          final destination = resolveDesktopUpdateDestination(
            encodedIdentity: DesktopBundleIdentity(
              version: "1.8.4",
              buildNumber: 24,
              sourceSha: "source",
              os: os,
              architecture: architecture,
            ).encode(),
            encodedChannel: channel.name,
          );
          if (os == DesktopBundleOs.linux) {
            expect(destination, isA<DesktopPackageManagerUpdate>());
          } else {
            expect(destination, isA<DesktopManualDownload>());
            final uri = (destination as DesktopManualDownload).uri;
            expect(uri.scheme, "https");
            expect(uri.host, "sesori.com");
            expect(uri.path, "/desktop/");
            expect(uri.fragment, "${channel.name}-${os.name}-${architecture.name}");
          }
        });
      }
    }
  }
}
