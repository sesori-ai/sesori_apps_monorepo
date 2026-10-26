import "dart:io";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  const String base = "https://storage.googleapis.com/sesori-ai-linux-packages/desktop-updates/k1/internal/linux-arm64";
  const DesktopBundleIdentity identity = DesktopBundleIdentity(
    version: "1.8.4",
    buildNumber: 24,
    sourceSha: "source",
    os: DesktopBundleOs.linux,
    architecture: DesktopBundleArchitecture.arm64,
  );
  late List<Uri> requested;

  DesktopUpdateFeedApi api({required Map<String, http.Response> responses}) => DesktopUpdateFeedApi(
    client: MockClient((request) async {
      requested.add(request.url);
      return responses[request.url.toString()] ?? http.Response("missing", HttpStatus.notFound);
    }),
    bundleSource: const _BundleSource(),
  );

  setUp(() => requested = <Uri>[]);

  test("fetches this channel and CPU's feed and its signature", () async {
    final DesktopUpdateFeed feed = await api(
      responses: {
        "$base/releases.internal.json": http.Response('{"Assets":[]}', HttpStatus.ok),
        "$base/releases.internal.json.sig": http.Response("c2lnbmF0dXJl\n", HttpStatus.ok),
      },
    ).fetchFeed(identity: identity);

    expect(String.fromCharCodes(feed.bytes), '{"Assets":[]}');
    expect(feed.signature, "c2lnbmF0dXJl");
    expect(requested.map((uri) => uri.toString()), [
      "$base/releases.internal.json",
      "$base/releases.internal.json.sig",
    ]);
  });

  test("names the macOS appcast for this channel and CPU without fetching it", () {
    final Uri appcast = api(responses: {}).appcastUri(
      identity: identity.copyWith(os: DesktopBundleOs.macos, architecture: DesktopBundleArchitecture.x64),
    );

    expect(
      appcast.toString(),
      "https://storage.googleapis.com/sesori-ai-linux-packages/desktop-updates/k1/internal/macos-x64/appcast.xml",
    );
    expect(requested, isEmpty);
  });

  test("a missing feed fails instead of reporting no update", () async {
    await expectLater(api(responses: {}).fetchFeed(identity: identity), throwsA(isA<HttpException>()));
  });

  test("downloads the named package into the staging file", () async {
    final Directory root = await Directory.systemTemp.createTemp("desktop-update-feed-api");
    addTearDown(() => root.delete(recursive: true));
    final File destination = File("${root.path}/sesori-desktop-1.8.5-internal-full.nupkg");

    await api(
      responses: {"$base/sesori-desktop-1.8.5-internal-full.nupkg": http.Response("package", HttpStatus.ok)},
    ).downloadPackage(
      identity: identity,
      fileName: "sesori-desktop-1.8.5-internal-full.nupkg",
      destination: destination,
    );

    expect(await destination.readAsString(), "package");
  });
}

class const _BundleSource() implements InstalledDesktopBundleSource {
  @override
  DesktopBundleIdentity? get compiledIdentity => null;

  @override
  DesktopReleaseChannel get channel => DesktopReleaseChannel.internal;

  @override
  bool get isAppImage => true;

  @override
  String get velopackLibraryPath => "unused";

  @override
  DesktopBundleIdentity readInstalledIdentity() => throw UnimplementedError();
}
