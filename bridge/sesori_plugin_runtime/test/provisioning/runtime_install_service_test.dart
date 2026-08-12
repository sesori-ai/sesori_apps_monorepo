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

class _FakeArchiveExtractor({required final bool success, required final bool packageDirectory})
    implements ArchiveExtractor {
  @override
  Future<ArchiveExtractionResult> extract({
    required String archivePath,
    required String stagingPath,
    required ArchiveFormat format,
  }) async {
    if (!success) {
      return const ArchiveExtractionResult.failure(reason: "powershell Expand-Archive exited with code 1: boom");
    }
    if (packageDirectory) {
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
    }
    return const CommandResult(exitCode: 0, stdout: "", stderr: "");
  }
}

const _asset = RuntimeAsset(
  assetName: "opencode-test.zip",
  format: ArchiveFormat.zip,
  sha256: "abc123",
  archiveBinaryName: "opencode",
  layout: RuntimeAssetLayout.singleBinary,
);

const _packageAsset = RuntimeAsset(
  assetName: "cursor-test.tar.gz",
  format: ArchiveFormat.tarGz,
  sha256: "def456",
  archiveBinaryName: "cursor-agent",
  layout: RuntimeAssetLayout.packageDirectory,
);

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
    _FakeCommandExecutor? cmd,
  }) {
    return RuntimeInstallService(
      downloadClient: _FakeDownloadClient(exception: downloadError),
      checksumValidator: _FakeChecksumValidator(valid: checksumValid),
      archiveExtractor: _FakeArchiveExtractor(success: extractSuccess, packageDirectory: packageDirectory),
      commandExecutor: cmd ?? _FakeCommandExecutor(),
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
      startAborted: abort ?? StartAbortSignal.never,
    );
  }

  test("places the binary, writes the sentinel, and emits phase progress", () async {
    final cmd = _FakeCommandExecutor();
    final events = await install(build(cmd: cmd)).toList();

    expect(File(p.join(versionDir(), "opencode")).existsSync(), isTrue);
    expect(
      File(p.join(versionDir(), RuntimeInstallService.sentinelFileName)).readAsStringSync(),
      equals("abc123"),
    );
    expect(events.whereType<ProvisionDownloading>(), isNotEmpty);
    expect(events.any((e) => e is ProvisionVerifying), isTrue);
    expect(events.any((e) => e is ProvisionExtracting), isTrue);
    if (!Platform.isWindows) {
      expect(cmd.chmodCalls, equals(1));
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
