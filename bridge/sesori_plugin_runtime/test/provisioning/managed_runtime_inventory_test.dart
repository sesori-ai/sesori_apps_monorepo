import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class const _StubManifest() extends RuntimeManifest {
  @override
  String get runtimeId => "opencode";

  @override
  String get displayName => "OpenCode";

  @override
  String get installDocsUrl => "https://opencode.ai/docs#install";

  @override
  String get pathExecutableName => "opencode";

  @override
  String get binaryFileName => "opencode";

  @override
  RuntimeVersion get minPathVersion => SemanticRuntimeVersion.parse(value: "1.0.0");

  @override
  RuntimeVersion get bundledVersion => SemanticRuntimeVersion.parse(value: "1.17.9");

  @override
  RuntimeVersion? parseVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => null;

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => "https://example.test/${asset.assetName}";
}

void main() {
  late Directory stateDir;
  const inventory = ManagedRuntimeInventory(manifest: _StubManifest());

  setUp(() async {
    stateDir = await Directory.systemTemp.createTemp("managed-inventory");
  });

  tearDown(() async {
    if (stateDir.existsSync()) await stateDir.delete(recursive: true);
  });

  Directory versionDir(String version) =>
      Directory(p.join(stateDir.path, "opencode", version))..createSync(recursive: true);

  void installPinned() {
    final pinned = versionDir("1.17.9");
    File(p.join(pinned.path, "opencode")).writeAsStringSync("BINARY");
    File(p.join(pinned.path, RuntimeInstallService.sentinelFileName)).writeAsStringSync("abc123");
  }

  test("reports nothing when the managed directory does not exist", () {
    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isFalse);
  });

  test("reports nothing when only the pinned version is installed", () {
    installPinned();

    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isFalse);
  });

  test("reports an outdated install when an older version remains", () {
    versionDir("1.16.0");

    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isTrue);
  });

  test("does not report an older directory when a pinned or newer version is present", () {
    versionDir("1.16.0");
    installPinned();
    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isFalse);

    versionDir("1.18.0");
    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isFalse);
  });

  test("repairs a partial pinned directory even without an older runtime", () {
    final pinned = versionDir("1.17.9");
    final sentinel = File(p.join(pinned.path, RuntimeInstallService.sentinelFileName));

    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isTrue);
    File(p.join(pinned.path, "opencode")).writeAsStringSync("BINARY");
    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isTrue);
    sentinel.writeAsStringSync("");
    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isTrue);
    sentinel.writeAsStringSync("abc123");
    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isFalse);
  });

  test("ignores stray files next to the version directories", () {
    File(p.join(stateDir.path, "opencode", "notes.txt"))
      ..createSync(recursive: true)
      ..writeAsStringSync("stray");

    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isFalse);
  });

  test("ignores installer staging and non-version directories", () {
    versionDir(".sesori-runtime-staging");
    versionDir("notes");

    expect(inventory.hasOutdatedVersion(stateDirectory: stateDir.path), isFalse);
  });

  test("lists installed versions newest first", () {
    versionDir("1.16.0");
    versionDir("1.17.9");
    versionDir("0.9.0");
    versionDir(".sesori-runtime-staging");

    expect(
      inventory.installedVersions(stateDirectory: stateDir.path).map((version) => version.raw),
      ["1.17.9", "1.16.0", "0.9.0"],
    );
  });

  test("lists nothing when the managed directory does not exist", () {
    expect(inventory.installedVersions(stateDirectory: stateDir.path), isEmpty);
  });
}
