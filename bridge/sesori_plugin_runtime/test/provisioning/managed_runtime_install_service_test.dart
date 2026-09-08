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

class _FakeCandidateValidator({
  required final RuntimeVersion? managedVersion,
  final Future<bool> Function(RuntimeCandidateValidationContext context)? onValidate,
}) implements RuntimeCandidateValidator {
  final List<RuntimeCandidateValidationContext> contexts = [];

  @override
  Future<bool> validate({required RuntimeCandidateValidationContext context}) {
    contexts.add(context);
    final callback = onValidate;
    return callback == null ? Future<bool>.value(managedVersion?.raw == "1.17.9") : callback(context);
  }
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
    required Duration archiveCommandTimeout,
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
    RuntimeCandidateValidator? candidateValidator,
  }) {
    final manifest = _StubManifest(hasAsset: hasAsset);
    return ManagedRuntimeInstallService(
      manifest: manifest,
      installService: RuntimeInstallService(
        downloadClient: _FakeDownloadClient(onDownload: onDownload),
        checksumValidator: _FakeChecksumValidator(valid: checksumValid),
        archiveExtractor: const _FakeArchiveExtractor(),
        commandExecutor: _FakeCommandExecutor(),
        candidateValidator: candidateValidator ?? _FakeCandidateValidator(managedVersion: managedVersion),
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

  test("validates a cached candidate in disposable managed staging", () async {
    installPinned();
    final validator = _FakeCandidateValidator(
      managedVersion: SemanticRuntimeVersion.parse(value: "1.17.9"),
      onValidate: (context) async {
        final stagingPath = p.join(stateDir.path, "opencode", ".sesori-runtime-staging");
        expect(context.executablePath, p.join(stateDir.path, "opencode", "1.17.9", "opencode"));
        expect(p.isWithin(stagingPath, context.workingDirectory), isTrue);
        expect(p.isWithin(stagingPath, context.stateDirectory), isTrue);
        expect(Directory(context.workingDirectory).existsSync(), isTrue);
        expect(Directory(context.stateDirectory).existsSync(), isTrue);
        return true;
      },
    );

    final events = await install(build(candidateValidator: validator));

    expect(events.whereType<ProvisionDownloading>(), isEmpty);
    expect(events.last, isA<ProvisionReady>());
    expect(validator.contexts, hasLength(1));
    expect(Directory(p.join(stateDir.path, "opencode", ".sesori-runtime-staging")).existsSync(), isFalse);
  });

  test("failed cached and downloaded validation preserve the installed pair and sentinel", () async {
    installPinned();
    var validationCalls = 0;
    final validator = _FakeCandidateValidator(
      managedVersion: null,
      onValidate: (context) async {
        validationCalls++;
        return false;
      },
    );

    final events = await install(build(candidateValidator: validator));

    expect(validationCalls, 2, reason: "both cached and downloaded candidates are validated");
    expect(events.last, isA<ProvisionFailed>());
    final pinnedPath = p.join(stateDir.path, "opencode", "1.17.9");
    expect(File(p.join(pinnedPath, "opencode")).readAsStringSync(), "BINARY");
    expect(File(p.join(pinnedPath, RuntimeInstallService.sentinelFileName)).readAsStringSync(), "abc123");
    expect(Directory(p.join(stateDir.path, "opencode", ".sesori-runtime-staging")).existsSync(), isFalse);
  });

  test("aborting cached validation preserves the installed pair and sentinel", () async {
    installPinned();
    final aborted = StartAbortController();
    final validationStarted = Completer<void>();
    final validationMaySettle = Completer<void>();
    final validator = _FakeCandidateValidator(
      managedVersion: null,
      onValidate: (context) async {
        validationStarted.complete();
        await validationMaySettle.future;
        if (context.abortSignal.isAborted) {
          throw const PluginStartAbortedException();
        }
        return true;
      },
    );
    final installing = build(candidateValidator: validator)
        .install(
          environment: const {},
          stateDirectory: stateDir.path,
          startAborted: aborted.signal,
          runtimeInUse: RuntimeInUseSignal.never,
        )
        .toList();

    await validationStarted.future;
    aborted.abort();
    validationMaySettle.complete();

    await expectLater(installing, throwsA(isA<PluginStartAbortedException>()));
    final pinnedPath = p.join(stateDir.path, "opencode", "1.17.9");
    expect(File(p.join(pinnedPath, "opencode")).readAsStringSync(), "BINARY");
    expect(File(p.join(pinnedPath, RuntimeInstallService.sentinelFileName)).readAsStringSync(), "abc123");
    expect(Directory(p.join(stateDir.path, "opencode", ".sesori-runtime-staging")).existsSync(), isFalse);
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
