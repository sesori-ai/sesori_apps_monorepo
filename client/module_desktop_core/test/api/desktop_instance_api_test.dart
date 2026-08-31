import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:isolate";

import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late Directory root;
  late _FixedApplicationSupportDirectory applicationSupportDirectory;
  final List<DesktopInstanceApi> apis = <DesktopInstanceApi>[];

  setUp(() {
    root = Directory.systemTemp.createTempSync("sesori_desktop_instance_");
    applicationSupportDirectory = _FixedApplicationSupportDirectory(directory: root);
  });

  tearDown(() async {
    for (final DesktopInstanceApi api in apis.reversed) {
      await api.dispose();
    }
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    apis.clear();
  });

  DesktopInstanceApi createApi() {
    final DesktopInstanceApi api = DesktopInstanceApi.forTesting(
      applicationSupportDirectory: applicationSupportDirectory,
      activationAttempts: 3,
      activationRetryDelay: const Duration(milliseconds: 1),
      connectTimeout: const Duration(milliseconds: 100),
      readTimeout: const Duration(milliseconds: 100),
    );
    apis.add(api);
    return api;
  }

  test("the secondary process signals the primary activation channel", () async {
    final DesktopInstanceApi primary = createApi();
    expect(await primary.tryAcquirePrimary(), isTrue);
    final Future<void> activation = primary.activationRequests.first;
    final Uri? packageConfig = await Isolate.packageConfig;
    if (packageConfig == null) {
      fail("The test isolate has no package configuration");
    }

    final ProcessResult secondary = await Process.run(
      Platform.resolvedExecutable,
      <String>[
        "--packages=${packageConfig.toFilePath()}",
        path.join("test", "support", "desktop_instance_secondary.dart"),
        root.path,
      ],
      workingDirectory: Directory.current.path,
    );

    expect(secondary.exitCode, 0, reason: secondary.stderr.toString());
    expect(secondary.stdout.toString().trim(), "secondaryActivated");
    await activation.timeout(const Duration(seconds: 1));
  });

  test("a killed owner releases its lock despite stale activation metadata", () async {
    final Uri? packageConfig = await Isolate.packageConfig;
    if (packageConfig == null) {
      fail("The test isolate has no package configuration");
    }
    final Process owner = await Process.start(
      Platform.resolvedExecutable,
      <String>[
        "--packages=${packageConfig.toFilePath()}",
        path.join("test", "support", "desktop_instance_owner.dart"),
        root.path,
      ],
      workingDirectory: Directory.current.path,
    );
    addTearDown(owner.kill);
    final String ready = await owner.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 20));
    expect(ready, "ready");

    expect(owner.kill(Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigkill), isTrue);
    await owner.exitCode;
    final DesktopInstanceApi replacement = createApi();

    expect(await replacement.tryAcquirePrimary(), isTrue);
  });

  test("signaling without a primary is bounded and returns false", () async {
    final DesktopInstanceApi api = createApi();

    expect(await api.signalPrimary(), isFalse);
  });
}

class _FixedApplicationSupportDirectory({required final Directory directory})
    implements DesktopApplicationSupportDirectory {
  @override
  Future<Directory> resolve() async => directory;
}
