import "dart:async";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class const _StubManifest({required final bool hasAsset}) implements RuntimeManifest {
  static const RuntimeAsset _asset = DirectBinaryRuntimeAsset(
    assetName: "opencode-test",
    sha256: "abc123",
  );

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
  RuntimeVersion? parseInstalledVersion({required String value}) => parseVersion(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => hasAsset ? _asset : null;

  @override
  bool supportsManagedInstallOn({required PlatformTarget target}) => hasAsset;

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => "https://example.test/${asset.assetName}";

  @override
  String githubReleaseAssetUrl({required String repository, required String tag, required RuntimeAsset asset}) =>
      "https://github.com/$repository/releases/download/$tag/${asset.assetName}";

  @override
  String managedBinaryPath({required String stateDirectory, required RuntimeVersion version}) {
    return p.join(stateDirectory, runtimeId, version.raw, binaryFileName);
  }
}

class const _StubInUseSignal({required final bool _inUse}) implements RuntimeInUseSignal {
  @override
  bool get isInUse => _inUse;
}

class _FakeValidator({required final RuntimeVersion? managedVersion}) implements RuntimeVersionValidator {
  final List<String> detectedExecutables = [];

  @override
  Future<RuntimeProbeOutcome> probe({
    required String executable,
    required Map<String, String>? environment,
  }) async {
    detectedExecutables.add(executable);
    return managedVersion == null ? const RuntimeProbeUnrecognized() : RuntimeProbeReady(version: managedVersion!);
  }

  @override
  Future<RuntimeVersion?> detectVersion({
    required String executable,
    required Map<String, String>? environment,
  }) async {
    detectedExecutables.add(executable);
    return managedVersion;
  }

  @override
  RuntimeVersion? parseVersionOutput({required String output}) => SemanticRuntimeVersion.tryParse(value: output);
}

class const _FakeDownloadClient({required final void Function()? _onDownload}) implements BinaryDownloadClient {
  @override
  Stream<DownloadProgress> download({required String url, required String destinationPath}) async* {
    _onDownload?.call();
    File(destinationPath).writeAsBytesSync(const [1, 2, 3, 4]);
    yield const DownloadProgress(receivedBytes: 4, totalBytes: 4);
  }
}

class const _FakeChecksumValidator({required final bool valid}) implements ChecksumValidator {
  @override
  Future<bool> verify({required String filePath, required String expectedHash}) async => valid;

  @override
  Future<String> computeSha256({required String filePath}) async => "deadbeef";
}

class const _FakeArchiveExtractor() implements ArchiveExtractor {
  @override
  Future<ArchiveExtractionResult> extract({
    required String archivePath,
    required String stagingPath,
    required ArchiveFormat format,
  }) async {
    Directory(stagingPath).createSync(recursive: true);
    File(p.join(stagingPath, "opencode")).writeAsStringSync("BINARY");
    return const ArchiveExtractionResult.success();
  }
}

class _FakeCommandExecutor() implements CommandExecutor {
  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    return const CommandResult(exitCode: 0, stdout: "", stderr: "");
  }
}

void main() {
  late Directory stateDir;

  setUp(() async {
    stateDir = await Directory.systemTemp.createTemp("install-service");
  });

  tearDown(() async {
    if (stateDir.existsSync()) {
      await stateDir.delete(recursive: true);
    }
  });

  ManagedRuntimeInstallService build({
    bool hasAsset = true,
    bool checksumValid = true,
    RuntimeVersion? managedVersion,
    RuntimeAssetResolver? assetResolver,
    void Function()? onDownload,
  }) {
    final manifest = _StubManifest(hasAsset: hasAsset);
    return ManagedRuntimeInstallService(
      manifest: manifest,
      versionValidator: _FakeValidator(managedVersion: managedVersion),
      installService: RuntimeInstallService(
        downloadClient: _FakeDownloadClient(onDownload: onDownload),
        checksumValidator: _FakeChecksumValidator(valid: checksumValid),
        archiveExtractor: const _FakeArchiveExtractor(),
        commandExecutor: _FakeCommandExecutor(),
        runtimeId: "opencode",
      ),
      cleaner: ManagedRuntimeCleaner(runtimeId: "opencode"),
      assetResolver: assetResolver ?? ({required target}) async => manifest.assetFor(target: target),
    );
  }

  Future<List<RuntimeProvisionProgress>> install(
    ManagedRuntimeInstallService service, {
    RuntimeInUseSignal runtimeInUse = RuntimeInUseSignal.never,
  }) {
    return service
        .install(
          environment: const {},
          stateDirectory: stateDir.path,
          startAborted: StartAbortSignal.never,
          runtimeInUse: runtimeInUse,
        )
        .toList();
  }

  Directory versionDir(String version) =>
      Directory(p.join(stateDir.path, "opencode", version))..createSync(recursive: true);

  /// Writes a healthy pinned install so the service takes its already-installed
  /// short-circuit instead of downloading.
  void installPinned() {
    final dir = versionDir("1.17.9");
    File(p.join(dir.path, "opencode")).writeAsStringSync("BINARY");
    File(p.join(dir.path, RuntimeInstallService.sentinelFileName)).writeAsStringSync("abc123");
  }

  test("installs, probes the placed binary, and ends ready", () async {
    final events = await install(build(managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9")));

    final binaryPath = p.join(stateDir.path, "opencode", "1.17.9", "opencode");
    expect(events.first, isA<ProvisionResolving>());
    expect(events.whereType<ProvisionDownloading>(), isNotEmpty);
    expect(events.last, isA<ProvisionReady>());
    expect((events.last as ProvisionReady).binaryPath, binaryPath);
    expect(File(binaryPath).existsSync(), isTrue);
  });

  test("fails when the platform has no published asset", () async {
    final events = await install(build(hasAsset: false));

    expect(events.last, isA<ProvisionFailed>());
    expect((events.last as ProvisionFailed).message, contains("no managed runtime for this platform"));
  });

  test("awaits async asset resolution and sanitizes resolver failures", () async {
    final events = await install(
      build(
        assetResolver: ({required target}) async {
          await Future<void>.delayed(Duration.zero);
          throw StateError("private host evidence");
        },
      ),
    );

    expect(events.last, isA<ProvisionFailed>());
    final message = (events.last as ProvisionFailed).message;
    expect(message, contains("Could not select the OpenCode runtime"));
    expect(message, isNot(contains("private host evidence")));
  });

  test("preserves an abort that occurs before asset resolution fails", () async {
    final aborted = StartAbortController();
    final resolverStarted = Completer<void>();
    final resolverMayFail = Completer<void>();
    final events =
        build(
              assetResolver: ({required target}) async {
                resolverStarted.complete();
                await resolverMayFail.future;
                throw StateError("resolver stopped");
              },
            )
            .install(
              environment: const {},
              stateDirectory: stateDir.path,
              startAborted: aborted.signal,
              runtimeInUse: RuntimeInUseSignal.never,
            )
            .toList();

    await resolverStarted.future;
    aborted.abort();
    resolverMayFail.complete();

    await expectLater(events, throwsA(isA<PluginStartAbortedException>()));
  });

  test("maps a checksum failure to a sanitized ProvisionFailed", () async {
    final events = await install(build(checksumValid: false));

    expect(events.last, isA<ProvisionFailed>());
    final message = (events.last as ProvisionFailed).message;
    expect(message, contains("Could not install the OpenCode runtime"));
    expect(message, isNot(contains("checksum")));
  });

  test("fails when the freshly placed binary does not run", () async {
    final events = await install(build(managedVersion: null));

    expect(events.last, isA<ProvisionFailed>());
    expect((events.last as ProvisionFailed).message, contains("not runnable"));
  });

  test("sweeps superseded managed versions after a healthy install", () async {
    final staleDir = versionDir("1.0.0");

    await install(build(managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9")));

    expect(staleDir.existsSync(), isFalse);
    expect(Directory(p.join(stateDir.path, "opencode", "1.17.9")).existsSync(), isTrue);
  });

  test("removes below-minimum versions before the download starts", () async {
    final obsoleteDir = versionDir("0.9.0");
    final supportedDir = versionDir("1.5.0");
    var downloaded = false;
    final service = build(
      managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9"),
      onDownload: () {
        downloaded = true;
        expect(obsoleteDir.existsSync(), isFalse, reason: "an obsolete version goes before bandwidth is spent");
        expect(
          supportedDir.existsSync(),
          isTrue,
          reason: "a supported version stays usable until the replacement lands",
        );
      },
    );

    await install(service);

    expect(downloaded, isTrue);
    expect(supportedDir.existsSync(), isFalse);
  });

  test("removes an obsolete version even when the install then fails", () async {
    final obsoleteDir = versionDir("0.9.0");

    final events = await install(build(checksumValid: false));

    expect(events.last, isA<ProvisionFailed>());
    expect(obsoleteDir.existsSync(), isFalse);
  });

  test("keeps an unparseable directory until the post-install sweep", () async {
    final stagingDir = versionDir(".sesori-runtime-staging");
    var stagingPresentAtDownload = false;
    final service = build(
      managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9"),
      onDownload: () => stagingPresentAtDownload = stagingDir.existsSync(),
    );

    await install(service);

    expect(stagingPresentAtDownload, isTrue);
    expect(stagingDir.existsSync(), isFalse);
  });

  test("keeps a supported superseded version while a generation is running", () async {
    final supportedDir = versionDir("1.5.0");
    final obsoleteDir = versionDir("0.9.0");

    await install(
      build(managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9")),
      runtimeInUse: const _StubInUseSignal(inUse: true),
    );

    expect(supportedDir.existsSync(), isTrue);
    expect(obsoleteDir.existsSync(), isFalse);
  });

  test("keeps a supported superseded version on the already-installed path too", () async {
    final supportedDir = versionDir("1.5.0");
    installPinned();

    final events = await install(
      build(managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9")),
      runtimeInUse: const _StubInUseSignal(inUse: true),
    );

    expect(events.whereType<ProvisionDownloading>(), isEmpty);
    expect(events.last, isA<ProvisionReady>());
    expect(supportedDir.existsSync(), isTrue);
  });

  test("reclaims a supported superseded version once no generation is running", () async {
    final supportedDir = versionDir("1.5.0");
    installPinned();

    await install(
      build(managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9")),
      runtimeInUse: const _StubInUseSignal(inUse: false),
    );

    expect(supportedDir.existsSync(), isFalse);
  });

  test("sweeps before the terminal event so an unsubscribing consumer cannot skip cleanup", () async {
    final staleDir = versionDir("1.0.0");
    final flow = build(managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9"));

    // Mirrors the lifecycle service, which stops listening at the terminal
    // event so the phone is not held up by post-install housekeeping.
    await flow
        .install(
          environment: const {},
          stateDirectory: stateDir.path,
          startAborted: StartAbortSignal.never,
          runtimeInUse: RuntimeInUseSignal.never,
        )
        .firstWhere((event) => event is ProvisionReady || event is ProvisionFailed);

    expect(staleDir.existsSync(), isFalse);
  });
}
