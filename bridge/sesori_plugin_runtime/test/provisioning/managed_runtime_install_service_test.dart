import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class _StubManifest implements RuntimeManifest {
  const _StubManifest({required this.hasAsset});

  final bool hasAsset;

  static const RuntimeAsset _asset = RuntimeAsset(
    assetName: "opencode-test.zip",
    format: ArchiveFormat.zip,
    sha256: "abc123",
    archiveBinaryName: "opencode",
    layout: RuntimeAssetLayout.singleBinary,
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
  RuntimeAsset? assetFor({required PlatformTarget target}) => hasAsset ? _asset : null;

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => "https://example.test/${asset.assetName}";

  @override
  String managedBinaryPath({required String stateDirectory}) {
    return p.join(stateDirectory, runtimeId, bundledVersion.toString(), binaryFileName);
  }
}

class _FakeValidator implements RuntimeVersionValidator {
  _FakeValidator({required this.managedVersion});

  final RuntimeVersion? managedVersion;
  final List<String> detectedExecutables = [];

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

class _FakeDownloadClient implements BinaryDownloadClient {
  const _FakeDownloadClient();

  @override
  Stream<DownloadProgress> download({required String url, required String destinationPath}) async* {
    File(destinationPath).writeAsBytesSync(const [1, 2, 3, 4]);
    yield const DownloadProgress(receivedBytes: 4, totalBytes: 4);
  }
}

class _FakeChecksumValidator implements ChecksumValidator {
  const _FakeChecksumValidator({required this.valid});

  final bool valid;

  @override
  Future<bool> verify({required String filePath, required String expectedHash}) async => valid;

  @override
  Future<String> computeSha256({required String filePath}) async => "deadbeef";
}

class _FakeArchiveExtractor implements ArchiveExtractor {
  const _FakeArchiveExtractor();

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

class _FakeCommandExecutor implements CommandExecutor {
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
  }) {
    return ManagedRuntimeInstallService(
      manifest: _StubManifest(hasAsset: hasAsset),
      versionValidator: _FakeValidator(managedVersion: managedVersion),
      installService: RuntimeInstallService(
        downloadClient: const _FakeDownloadClient(),
        checksumValidator: _FakeChecksumValidator(valid: checksumValid),
        archiveExtractor: const _FakeArchiveExtractor(),
        commandExecutor: _FakeCommandExecutor(),
        runtimeId: "opencode",
      ),
      cleaner: ManagedRuntimeCleaner(runtimeId: "opencode"),
    );
  }

  Future<List<RuntimeProvisionProgress>> install(ManagedRuntimeInstallService service) {
    return service        .install(environment: const {}, stateDirectory: stateDir.path, startAborted: StartAbortSignal.never)
        .toList();
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
    final staleDir = Directory(p.join(stateDir.path, "opencode", "1.0.0"))..createSync(recursive: true);

    await install(build(managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9")));

    expect(staleDir.existsSync(), isFalse);
    expect(Directory(p.join(stateDir.path, "opencode", "1.17.9")).existsSync(), isTrue);
  });

  test("sweeps before the terminal event so an unsubscribing consumer cannot skip cleanup", () async {
    final staleDir = Directory(p.join(stateDir.path, "opencode", "1.0.0"))..createSync(recursive: true);
    final flow = build(managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9"));

    // Mirrors the lifecycle service, which stops listening at the terminal
    // event so the phone is not held up by post-install housekeeping.
    await flow
        .install(environment: const {}, stateDirectory: stateDir.path, startAborted: StartAbortSignal.never)
        .firstWhere((event) => event is ProvisionReady || event is ProvisionFailed);

    expect(staleDir.existsSync(), isFalse);
  });
}
