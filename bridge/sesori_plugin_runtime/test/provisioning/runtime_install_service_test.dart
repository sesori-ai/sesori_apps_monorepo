import "dart:async";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class _FakeDownloadClient({final DownloadException? exception}) implements BinaryDownloadClient {
  static const int _byteCount = 4;
  static const List<int> _bytes = [1, 2, 3, 4];

  @override
  Stream<DownloadProgress> download({required String url, required String destinationPath}) async* {
    final ex = exception;
    if (ex != null) {
      throw ex;
    }
    File(destinationPath).writeAsBytesSync(_bytes);
    yield const DownloadProgress(receivedBytes: _byteCount, totalBytes: _byteCount);
  }
}

class _FakeChecksumValidator({required final bool valid}) implements ChecksumValidator {
  @override
  Future<bool> verify({required String filePath, required String expectedHash}) async => valid;

  @override
  Future<String> computeSha256({required String filePath}) async => "deadbeef";
}

class _FakeArchiveExtractor({
  required final bool success,
  required final bool packageDirectory,
  final bool rootPackage = false,
}) implements ArchiveExtractor {
  int extractCalls = 0;
  final List<Duration> observedTimeouts = [];

  @override
  Future<ArchiveExtractionResult> extract({
    required String archivePath,
    required String stagingPath,
    required ArchiveFormat format,
    required Duration archiveCommandTimeout,
  }) async {
    extractCalls++;
    observedTimeouts.add(archiveCommandTimeout);
    if (!success) {
      return const ArchiveExtractionResult.failure(reason: "powershell Expand-Archive exited with code 1: boom");
    }
    if (rootPackage) {
      final bin = Directory(p.join(stagingPath, "bin"))..createSync(recursive: true);
      File(p.join(bin.path, "codex")).writeAsStringSync("BINARY");
      File(p.join(bin.path, "codex-code-mode-host")).writeAsStringSync("SIDECAR");
      final resources = Directory(p.join(stagingPath, "codex-resources"))..createSync();
      File(p.join(resources.path, "resource")).writeAsStringSync("RESOURCE");
    } else if (packageDirectory) {
      final package = Directory(p.join(stagingPath, "dist-package"))..createSync(recursive: true);
      File(p.join(package.path, "cursor-agent")).writeAsStringSync("BINARY");
      File(p.join(package.path, "node-runtime")).writeAsStringSync("SIBLING");
    } else {
      Directory(stagingPath).createSync(recursive: true);
      File(p.join(stagingPath, "opencode")).writeAsStringSync("BINARY");
    }
    return const ArchiveExtractionResult.success();
  }
}

class _FakeCommandExecutor() implements CommandExecutor {
  int chmodCalls = 0;
  final List<List<String>> chmodArguments = [];

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    if (executable == "chmod") {
      chmodCalls++;
      chmodArguments.add(arguments);
    }
    return const CommandResult(exitCode: 0, stdout: "", stderr: "");
  }
}

class _FakeCandidateValidator({
  final bool valid = true,
  final Future<bool> Function(RuntimeCandidateValidationContext context)? onValidate,
}) implements RuntimeCandidateValidator {
  final List<RuntimeCandidateValidationContext> contexts = [];

  @override
  Future<bool> validate({required RuntimeCandidateValidationContext context}) {
    contexts.add(context);
    final callback = onValidate;
    return callback == null ? Future<bool>.value(valid) : callback(context);
  }
}

const _asset = ArchiveRuntimeAsset(
  assetName: "opencode-test.zip",
  format: ArchiveFormat.zip,
  archiveCommandTimeout: Duration(minutes: 5),
  sha256: "abc123",
  archiveBinaryName: "opencode",
  layout: RuntimeArchiveLayout.singleBinary,
);

const _packageAsset = ArchiveRuntimeAsset(
  assetName: "cursor-test.tar.gz",
  format: ArchiveFormat.tarGz,
  archiveCommandTimeout: Duration(minutes: 2),
  sha256: "def456",
  archiveBinaryName: "cursor-agent",
  layout: RuntimeArchiveLayout.packageDirectory,
);

const _rootPackageAsset = ArchiveRuntimeAsset(
  assetName: "codex-package-test.tar.gz",
  format: ArchiveFormat.tarGz,
  archiveCommandTimeout: Duration(minutes: 2),
  sha256: "fed321",
  archiveBinaryName: "bin/codex",
  layout: RuntimeArchiveLayout.packageDirectory,
);

const _directAsset = DirectBinaryRuntimeAsset(assetName: "omp-test", sha256: "789abc");

void main() {
  late Directory managedDir;

  setUp(() async {
    managedDir = await Directory.systemTemp.createTemp("runtime-install");
  });

  tearDown(() async {
    if (managedDir.existsSync()) {
      await managedDir.delete(recursive: true);
    }
  });

  RuntimeInstallService build({
    DownloadException? downloadError,
    bool checksumValid = true,
    bool extractSuccess = true,
    bool packageDirectory = false,
    bool rootPackage = false,
    _FakeCommandExecutor? cmd,
    _FakeArchiveExtractor? extractor,
    RuntimeCandidateValidator? candidateValidator,
  }) {
    return RuntimeInstallService(
      downloadClient: _FakeDownloadClient(exception: downloadError),
      checksumValidator: _FakeChecksumValidator(valid: checksumValid),
      archiveExtractor:
          extractor ??
          _FakeArchiveExtractor(
            success: extractSuccess,
            packageDirectory: packageDirectory,
            rootPackage: rootPackage,
          ),
      commandExecutor: cmd ?? _FakeCommandExecutor(),
      candidateValidator: candidateValidator ?? _FakeCandidateValidator(),
      runtimeId: "opencode",
    );
  }

  String versionDir() => p.join(managedDir.path, "1.17.9");

  Stream<RuntimeProvisionProgress> install(RuntimeInstallService service, {StartAbortSignal? abort}) {
    return service.install(
      managedDir: managedDir.path,
      versionDir: versionDir(),
      binaryFileName: "opencode",
      downloadUrl: "https://example.test/opencode-test.zip",
      asset: _asset,
      environment: const {"PATH": "/runtime-test"},
      startAborted: abort ?? StartAbortSignal.never,
    );
  }

  test("places the binary, writes the sentinel, and emits phase progress", () async {
    final cmd = _FakeCommandExecutor();
    final extractor = _FakeArchiveExtractor(success: true, packageDirectory: false);
    final events = await install(build(cmd: cmd, extractor: extractor)).toList();
    expect(extractor.observedTimeouts, [_asset.archiveCommandTimeout]);

    expect(File(p.join(versionDir(), "opencode")).existsSync(), isTrue);
    expect(
      File(p.join(versionDir(), RuntimeInstallService.sentinelFileName)).readAsStringSync(),
      equals("abc123"),
    );
    expect(events.whereType<ProvisionDownloading>(), isNotEmpty);
    expect(events.any((e) => e is ProvisionVerifying), isTrue);
    expect(events.any((e) => e is ProvisionExtracting), isTrue);
    if (!Platform.isWindows) {
      expect(cmd.chmodCalls, equals(4));
    }
    // The download + staging scratch are cleaned up. The download carries the
    // archive's extension so PowerShell Expand-Archive accepts it on Windows.
    expect(
      File(p.join(managedDir.path, ".sesori-runtime-download${_asset.format.fileExtension}")).existsSync(),
      isFalse,
    );
    expect(Directory(p.join(managedDir.path, ".sesori-runtime-staging")).existsSync(), isFalse);
  });

  test("places a package directory with the entry binary and its siblings", () async {
    final staleFile = File(p.join(versionDir(), "stale"))
      ..createSync(recursive: true)
      ..writeAsStringSync("OLD");

    await build(packageDirectory: true)
        .install(
          managedDir: managedDir.path,
          versionDir: versionDir(),
          binaryFileName: "cursor-agent",
          downloadUrl: "https://example.test/cursor-test.tar.gz",
          asset: _packageAsset,
          environment: const {},
          startAborted: StartAbortSignal.never,
        )
        .drain<void>();

    expect(File(p.join(versionDir(), "cursor-agent")).readAsStringSync(), "BINARY");
    expect(File(p.join(versionDir(), "node-runtime")).readAsStringSync(), "SIBLING");
    expect(staleFile.existsSync(), isFalse);
    expect(
      File(p.join(versionDir(), RuntimeInstallService.sentinelFileName)).readAsStringSync(),
      "def456",
    );
  });

  test("places an archive-root package identified by a nested entry path", () async {
    final staleFile = File(p.join(versionDir(), "stale"))
      ..createSync(recursive: true)
      ..writeAsStringSync("OLD");

    await build(rootPackage: true)
        .install(
          managedDir: managedDir.path,
          versionDir: versionDir(),
          binaryFileName: p.join("bin", "codex"),
          downloadUrl: "https://example.test/codex-package-test.tar.gz",
          asset: _rootPackageAsset,
          environment: const {},
          startAborted: StartAbortSignal.never,
        )
        .drain<void>();

    expect(File(p.join(versionDir(), "bin", "codex")).readAsStringSync(), "BINARY");
    expect(File(p.join(versionDir(), "bin", "codex-code-mode-host")).readAsStringSync(), "SIDECAR");
    expect(File(p.join(versionDir(), "codex-resources", "resource")).readAsStringSync(), "RESOURCE");
    expect(staleFile.existsSync(), isFalse);
    expect(
      File(p.join(versionDir(), RuntimeInstallService.sentinelFileName)).readAsStringSync(),
      "fed321",
    );
  });

  test("places a direct binary without extraction and cleans stale staging", () async {
    final extractor = _FakeArchiveExtractor(success: true, packageDirectory: false);
    final staleStaging = Directory(p.join(managedDir.path, ".sesori-runtime-staging"))..createSync(recursive: true);
    File(p.join(staleStaging.path, "stale")).writeAsStringSync("OLD");

    final events = await build(extractor: extractor)
        .install(
          managedDir: managedDir.path,
          versionDir: versionDir(),
          binaryFileName: "omp",
          downloadUrl: "https://example.test/omp-test",
          asset: _directAsset,
          environment: const {},
          startAborted: StartAbortSignal.never,
        )
        .toList();

    expect(File(p.join(versionDir(), "omp")).readAsBytesSync(), [1, 2, 3, 4]);
    expect(File(p.join(versionDir(), RuntimeInstallService.sentinelFileName)).readAsStringSync(), "789abc");
    expect(events.any((event) => event is ProvisionExtracting), isFalse);
    expect(extractor.extractCalls, 0);
    expect(staleStaging.existsSync(), isFalse);
    expect(File(p.join(managedDir.path, ".sesori-runtime-download")).existsSync(), isFalse);
  });

  test("places a direct Windows executable under the canonical exe name", () async {
    await build()
        .install(
          managedDir: managedDir.path,
          versionDir: versionDir(),
          binaryFileName: "omp.exe",
          downloadUrl: "https://example.test/omp-test.exe",
          asset: _directAsset,
          environment: const {},
          startAborted: StartAbortSignal.never,
        )
        .drain<void>();

    expect(File(p.join(versionDir(), "omp.exe")).existsSync(), isTrue);
  });

  test("does not place a direct binary when checksum verification fails", () async {
    await expectLater(
      build(checksumValid: false)
          .install(
            managedDir: managedDir.path,
            versionDir: versionDir(),
            binaryFileName: "omp",
            downloadUrl: "https://example.test/omp-test",
            asset: _directAsset,
            environment: const {},
            startAborted: StartAbortSignal.never,
          )
          .drain<void>(),
      throwsA(isA<RuntimeInstallException>()),
    );
    expect(File(p.join(versionDir(), "omp")).existsSync(), isFalse);
    expect(File(p.join(managedDir.path, ".sesori-runtime-download")).existsSync(), isFalse);
  });

  test("cancels a direct binary install before placement", () async {
    final controller = StartAbortController()..abort();

    await expectLater(
      build()
          .install(
            managedDir: managedDir.path,
            versionDir: versionDir(),
            binaryFileName: "omp",
            downloadUrl: "https://example.test/omp-test",
            asset: _directAsset,
            environment: const {},
            startAborted: controller.signal,
          )
          .drain<void>(),
      throwsA(isA<PluginStartAbortedException>()),
    );
    expect(File(p.join(versionDir(), "omp")).existsSync(), isFalse);
    expect(File(p.join(managedDir.path, ".sesori-runtime-download")).existsSync(), isFalse);
  });

  test("validates a hardened candidate inside private disposable staging before placement", () async {
    final cmd = _FakeCommandExecutor();
    final validator = _FakeCandidateValidator(
      onValidate: (context) async {
        final stagingPath = p.join(managedDir.path, ".sesori-runtime-staging");
        expect(context.executablePath, p.join(stagingPath, "candidate", "opencode"));
        expect(p.isWithin(stagingPath, context.workingDirectory), isTrue);
        expect(p.isWithin(stagingPath, context.stateDirectory), isTrue);
        expect(context.environment, const {"PATH": "/runtime-test"});
        expect(File(context.executablePath).existsSync(), isTrue);
        expect(Directory(context.workingDirectory).existsSync(), isTrue);
        expect(Directory(context.stateDirectory).existsSync(), isTrue);
        expect(File(p.join(versionDir(), "old-binary")).existsSync(), isTrue);
        if (!Platform.isWindows) {
          expect(cmd.chmodArguments, [
            ["700", stagingPath],
            ["+x", context.executablePath],
            ["700", context.workingDirectory],
            ["700", context.stateDirectory],
          ]);
        }
        return true;
      },
    );
    File(p.join(versionDir(), "old-binary"))
      ..createSync(recursive: true)
      ..writeAsStringSync("OLD");

    await install(build(cmd: cmd, candidateValidator: validator)).drain<void>();

    expect(validator.contexts, hasLength(1));
    expect(Directory(p.join(managedDir.path, ".sesori-runtime-staging")).existsSync(), isFalse);
    expect(File(p.join(versionDir(), "old-binary")).existsSync(), isFalse);
  });

  test("failed candidate validation preserves the prior package and sentinel", () async {
    final oldBinary = File(p.join(versionDir(), "opencode"))
      ..createSync(recursive: true)
      ..writeAsStringSync("OLD");
    final oldSibling = File(p.join(versionDir(), "sibling"))..writeAsStringSync("OLD-SIBLING");
    final oldSentinel = File(p.join(versionDir(), RuntimeInstallService.sentinelFileName))
      ..writeAsStringSync("old-hash");

    await expectLater(
      install(build(candidateValidator: _FakeCandidateValidator(valid: false))).drain<void>(),
      throwsA(isA<RuntimeInstallException>()),
    );

    expect(oldBinary.readAsStringSync(), "OLD");
    expect(oldSibling.readAsStringSync(), "OLD-SIBLING");
    expect(oldSentinel.readAsStringSync(), "old-hash");
    expect(Directory(p.join(managedDir.path, ".sesori-runtime-staging")).existsSync(), isFalse);
  });

  test("awaits abort-aware validation and cleanup without touching the prior install", () async {
    final aborted = StartAbortController();
    final validationStarted = Completer<void>();
    final validationMaySettle = Completer<void>();
    final oldBinary = File(p.join(versionDir(), "opencode"))
      ..createSync(recursive: true)
      ..writeAsStringSync("OLD");
    final oldSentinel = File(p.join(versionDir(), RuntimeInstallService.sentinelFileName))
      ..writeAsStringSync("old-hash");
    final validator = _FakeCandidateValidator(
      onValidate: (context) async {
        expect(context.abortSignal, same(aborted.signal));
        validationStarted.complete();
        await validationMaySettle.future;
        return true;
      },
    );
    final installing = install(build(candidateValidator: validator), abort: aborted.signal).drain<void>();

    await validationStarted.future;
    aborted.abort();
    expect(Directory(p.join(managedDir.path, ".sesori-runtime-staging")).existsSync(), isTrue);
    expect(oldBinary.readAsStringSync(), "OLD");
    validationMaySettle.complete();

    await expectLater(installing, throwsA(isA<PluginStartAbortedException>()));
    expect(oldBinary.readAsStringSync(), "OLD");
    expect(oldSentinel.readAsStringSync(), "old-hash");
    expect(Directory(p.join(managedDir.path, ".sesori-runtime-staging")).existsSync(), isFalse);
  });

  test("isInstalled is false before, true after, and rejects a hash mismatch", () async {
    final service = build();
    expect(service.isInstalled(versionDir: versionDir(), binaryFileName: "opencode", sha256: "abc123"), isFalse);

    await install(service).drain<void>();

    expect(service.isInstalled(versionDir: versionDir(), binaryFileName: "opencode", sha256: "abc123"), isTrue);
    expect(service.isInstalled(versionDir: versionDir(), binaryFileName: "opencode", sha256: "different"), isFalse);
  });

  test("throws when checksum verification fails", () async {
    await expectLater(
      install(build(checksumValid: false)).drain<void>(),
      throwsA(isA<RuntimeInstallException>()),
    );
    expect(File(p.join(versionDir(), "opencode")).existsSync(), isFalse);
  });

  test("throws when extraction fails, surfacing the underlying reason", () async {
    await expectLater(
      install(build(extractSuccess: false)).drain<void>(),
      throwsA(
        isA<RuntimeInstallException>().having(
          (e) => e.message,
          "message",
          allOf(contains("failed to extract"), contains("Expand-Archive exited with code 1: boom")),
        ),
      ),
    );
  });

  test("maps a download failure to an install exception", () async {
    final service = build(
      downloadError: const DownloadException(kind: DownloadFailureKind.network, message: "offline"),
    );
    await expectLater(install(service).drain<void>(), throwsA(isA<RuntimeInstallException>()));
  });

  test("aborts when the start-abort signal fires", () async {
    final controller = StartAbortController()..abort();
    await expectLater(
      install(build(), abort: controller.signal).drain<void>(),
      throwsA(isA<PluginStartAbortedException>()),
    );
  });
}
