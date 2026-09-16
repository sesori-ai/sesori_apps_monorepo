import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  test("source builds have no guessed download destination", () {
    expect(
      DesktopUpdateDestination.forBundle(identity: null, channel: DesktopReleaseChannel.stable),
      isA<DesktopDevelopmentUpdate>(),
    );
  });
  for (final os in DesktopBundleOs.values) {
    for (final architecture in DesktopBundleArchitecture.values) {
      for (final channel in DesktopReleaseChannel.values) {
        test("${channel.name}/${os.name}/${architecture.name} selects its official index section", () {
          final destination = DesktopUpdateDestination.forBundle(
            identity: DesktopBundleIdentity(
              version: "1.8.4",
              buildNumber: 24,
              sourceSha: "source",
              os: os,
              architecture: architecture,
            ),
            channel: channel,
          );
          if (os == DesktopBundleOs.linux) {
            expect(destination, isA<DesktopPackageManagerUpdate>());
          } else {
            expect(destination, isA<DesktopManualDownload>());
            final uri = (destination as DesktopManualDownload).uri;
            expect(uri.scheme, "https");
            expect(uri.host, "github.com");
            expect(uri.path, "/sesori-ai/sesori_apps_monorepo/blob/main/docs/desktop/downloads.md");
            expect(uri.fragment, "${channel.name}-${os.name}-${architecture.name}");
          }
        });
      }
    }
  }
}
