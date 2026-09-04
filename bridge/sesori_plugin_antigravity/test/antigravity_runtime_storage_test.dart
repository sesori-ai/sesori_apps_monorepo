import "dart:io";

import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  const target = PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64);
  const storage = AntigravityRuntimeStorage();
  late Directory temporaryDirectory;

  setUp(() => temporaryDirectory = Directory.systemTemp.createTempSync("antigravity-storage-"));
  tearDown(() {
    if (temporaryDirectory.existsSync()) temporaryDirectory.deleteSync(recursive: true);
  });

  ({String server, String harness}) writePair(Directory directory) {
    final server = p.join(directory.path, AntigravityRelease.serverFileName(target: target));
    final harness = p.join(directory.path, AntigravityRelease.harnessFileName(target: target));
    File(server).writeAsStringSync("server");
    File(harness).writeAsStringSync("harness");
    return (server: server, harness: harness);
  }

  test("inspects a regular official sibling pair", () {
    final paths = writePair(temporaryDirectory);
    final result = storage.inspectPair(serverPath: paths.server, target: target) as AntigravityRuntimePairFound;
    expect(
      (result.pair.serverPath, result.pair.harnessPath, result.pair.target),
      (File(paths.server).resolveSymbolicLinksSync(), File(paths.harness).resolveSymbolicLinksSync(), target),
    );
  });

  test("distinguishes missing server and harness files", () {
    final server = p.join(temporaryDirectory.path, AntigravityRelease.serverFileName(target: target));
    final missingServer = storage.inspectPair(serverPath: server, target: target) as AntigravityRuntimePairMissing;
    expect(missingServer.component, AntigravityRuntimeComponent.server);
    File(server).writeAsStringSync("server");
    final missingHarness = storage.inspectPair(serverPath: server, target: target) as AntigravityRuntimePairMissing;
    expect(missingHarness.component, AntigravityRuntimeComponent.harness);
  });

  test("rejects non-regular pair members", () {
    final server = p.join(temporaryDirectory.path, AntigravityRelease.serverFileName(target: target));
    final harness = p.join(temporaryDirectory.path, AntigravityRelease.harnessFileName(target: target));
    Directory(server).createSync();
    final badServer = storage.inspectPair(serverPath: server, target: target) as AntigravityRuntimePairInvalid;
    expect(badServer.reason, AntigravityRuntimePairInvalidReason.notAFile);
    Directory(server).deleteSync();
    File(server).writeAsStringSync("server");
    Directory(harness).createSync();
    final badHarness = storage.inspectPair(serverPath: server, target: target) as AntigravityRuntimePairInvalid;
    expect(badHarness.reason, AntigravityRuntimePairInvalidReason.notAFile);
  });

  test("rejects a server with the wrong official filename", () {
    final result = storage.inspectPair(
      serverPath: p.join(temporaryDirectory.path, "renamed-server"),
      target: target,
    ) as AntigravityRuntimePairInvalid;
    expect(
      (result.component, result.reason),
      (
        AntigravityRuntimeComponent.server,
        AntigravityRuntimePairInvalidReason.wrongName,
      ),
    );
  });

  test("matches official Windows filenames case-insensitively", () {
    const windowsTarget = PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64);
    final missing = storage.inspectPair(
      serverPath: r"C:\runtime\AGY_ACP_SERVER.EXE",
      target: windowsTarget,
    );
    expect(missing, isA<AntigravityRuntimePairMissing>());

    if (!Platform.isWindows) return;
    final server = p.join(
      temporaryDirectory.path,
      AntigravityRelease.serverFileName(target: windowsTarget).toUpperCase(),
    );
    final harness = p.join(
      temporaryDirectory.path,
      AntigravityRelease.harnessFileName(target: windowsTarget).toUpperCase(),
    );
    File(server).writeAsStringSync("server");
    File(harness).writeAsStringSync("harness");
    expect(
      storage.inspectPair(serverPath: server, target: windowsTarget),
      isA<AntigravityRuntimePairFound>(),
    );
  });

  test("rejects wrong resolved names and identical members", () {
    if (Platform.isWindows) return;
    final realDirectory = Directory(p.join(temporaryDirectory.path, "real"))..createSync();
    final requestedServer = p.join(temporaryDirectory.path, AntigravityRelease.serverFileName(target: target));
    final requestedHarness = p.join(temporaryDirectory.path, AntigravityRelease.harnessFileName(target: target));

    final renamedServer = p.join(realDirectory.path, "renamed-server");
    final officialHarness = p.join(realDirectory.path, AntigravityRelease.harnessFileName(target: target));
    File(renamedServer).writeAsStringSync("server");
    File(officialHarness).writeAsStringSync("harness");
    Link(requestedServer).createSync(renamedServer);
    Link(requestedHarness).createSync(officialHarness);
    final wrongServer =
        storage.inspectPair(serverPath: requestedServer, target: target) as AntigravityRuntimePairInvalid;
    expect(
      (wrongServer.component, wrongServer.reason),
      (
        AntigravityRuntimeComponent.server,
        AntigravityRuntimePairInvalidReason.wrongName,
      ),
    );

    Link(requestedServer).deleteSync();
    Link(requestedHarness).deleteSync();
    final officialServer = p.join(realDirectory.path, AntigravityRelease.serverFileName(target: target));
    final renamedHarness = p.join(realDirectory.path, "renamed-harness");
    File(officialServer).writeAsStringSync("server");
    File(renamedHarness).writeAsStringSync("harness");
    Link(requestedServer).createSync(officialServer);
    Link(requestedHarness).createSync(renamedHarness);
    final wrongHarness =
        storage.inspectPair(serverPath: requestedServer, target: target) as AntigravityRuntimePairInvalid;
    expect(
      (wrongHarness.component, wrongHarness.reason),
      (
        AntigravityRuntimeComponent.harness,
        AntigravityRuntimePairInvalidReason.wrongName,
      ),
    );

    Link(requestedServer).deleteSync();
    Link(requestedHarness).deleteSync();
    final sharedFile = p.join(realDirectory.path, "shared");
    File(sharedFile).writeAsStringSync("shared");
    Link(requestedServer).createSync(sharedFile);
    Link(requestedHarness).createSync(sharedFile);
    final identical = storage.inspectPair(serverPath: requestedServer, target: target) as AntigravityRuntimePairInvalid;
    expect(
      (identical.component, identical.reason),
      (
        AntigravityRuntimeComponent.harness,
        AntigravityRuntimePairInvalidReason.notDistinct,
      ),
    );
  });

  test("rejects a harness whose resolved path is not a sibling", () {
    if (Platform.isWindows) return;
    final elsewhere = Directory(p.join(temporaryDirectory.path, "elsewhere"))..createSync();
    final server = p.join(temporaryDirectory.path, AntigravityRelease.serverFileName(target: target));
    File(server).writeAsStringSync("server");
    final externalHarness = p.join(elsewhere.path, AntigravityRelease.harnessFileName(target: target));
    File(externalHarness).writeAsStringSync("harness");
    Link(p.join(temporaryDirectory.path, AntigravityRelease.harnessFileName(target: target)))
        .createSync(externalHarness);

    final result = storage.inspectPair(serverPath: server, target: target) as AntigravityRuntimePairInvalid;
    expect(result.reason, AntigravityRuntimePairInvalidReason.notSiblings);
  });

  test("PATH uses the first server hit and requires its sibling", () {
    final missingDirectory = Directory(p.join(temporaryDirectory.path, "missing"))..createSync();
    final pairDirectory = Directory(p.join(temporaryDirectory.path, "pair"))..createSync();
    final paths = writePair(pairDirectory);
    final separator = Platform.isWindows ? ";" : ":";
    final found = storage.findOnPath(
      environment: {
        "PATH": [missingDirectory.path, pairDirectory.path].join(separator),
      },
      target: target,
    ) as AntigravityRuntimePairFound;
    expect(found.pair.serverPath, File(paths.server).resolveSymbolicLinksSync());

    final shadowDirectory = Directory(p.join(temporaryDirectory.path, "shadow"))..createSync();
    File(p.join(shadowDirectory.path, AntigravityRelease.serverFileName(target: target))).writeAsStringSync("server");
    final shadowed = storage.findOnPath(
      environment: {
        "PATH": [shadowDirectory.path, pairDirectory.path].join(separator),
      },
      target: target,
    );
    expect(shadowed, isA<AntigravityRuntimePairMissing>());
    expect(storage.findOnPath(environment: const {}, target: target), isA<AntigravityRuntimePairMissing>());
  });
}
