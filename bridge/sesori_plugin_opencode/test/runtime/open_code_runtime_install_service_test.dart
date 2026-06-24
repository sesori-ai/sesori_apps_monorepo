import "dart:io";

import "package:opencode_plugin/src/runtime/open_code_runtime_install_service.dart";
import "package:opencode_plugin/src/runtime/open_code_runtime_manifest.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class _FakeDownloadClient implements BinaryDownloadClient {
  _FakeDownloadClient({this.exception});

  static const int _byteCount = 4;
  static const List<int> _bytes = [1, 2, 3, 4];
  final DownloadException? exception;

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

class _FakeChecksumValidator implements ChecksumValidator {
  _FakeChecksumValidator({required this.valid});

  final bool valid;

  @override
  Future<bool> verify({required String filePath, required String expectedHash}) async => valid;

  @override
  Future<String> computeSha256({required String filePath}) async => "deadbeef";
}

class _FakeArchiveExtractor implements ArchiveExtractor {
  _FakeArchiveExtractor({required this.success});

  final bool success;

  @override
  Future<ArchiveExtractionResult> extract({
    required String archivePath,
    required String stagingPath,
    required ArchiveFormat format,
  }) async {
    if (!success) {
      return const ArchiveExtractionResult.failure("powershell Expand-Archive exited with code 1: boom");
    }
    Directory(stagingPath).createSync(recursive: true);
    File(p.join(stagingPath, "opencode")).writeAsStringSync("BINARY");
    return const ArchiveExtractionResult.success();
  }
}

class _FakeCommandExecutor implements CommandExecutor {
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

const _asset = OpenCodeRuntimeAsset(
  assetName: "opencode-test.zip",
  format: ArchiveFormat.zip,
  sha256: "abc123",
);

void main() {
  late Directory managedDir;

  setUp(() async {
    managedDir = await Directory.systemTemp.createTemp("opencode-install");
  });

  tearDown(() async {
    if (managedDir.existsSync()) {
      await managedDir.delete(recursive: true);
    }
  });

  OpenCodeRuntimeInstallService build({
    DownloadException? downloadError,
    bool checksumValid = true,
    bool extractSuccess = true,
    _FakeCommandExecutor? cmd,
  }) {
    return OpenCodeRuntimeInstallService(
      downloadClient: _FakeDownloadClient(exception: downloadError),
      checksumValidator: _FakeChecksumValidator(valid: checksumValid),
      archiveExtractor: _FakeArchiveExtractor(success: extractSuccess),
      commandExecutor: cmd ?? _FakeCommandExecutor(),
    );
  }

  String versionDir() => p.join(managedDir.path, "1.17.9");

  Stream<RuntimeProvisionProgress> install(OpenCodeRuntimeInstallService service, {StartAbortSignal? abort}) {
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
      File(p.join(versionDir(), OpenCodeRuntimeInstallService.sentinelFileName)).readAsStringSync(),
      equals("abc123"),
    );
    expect(events.whereType<ProvisionDownloading>(), isNotEmpty);
    expect(events.any((e) => e is ProvisionVerifying), isTrue);
    expect(events.any((e) => e is ProvisionExtracting), isTrue);
    if (!Platform.isWindows) {
      expect(cmd.chmodCalls, equals(1));
    }
    // The download + staging scratch are cleaned up.
    expect(File(p.join(managedDir.path, ".opencode-runtime-download")).existsSync(), isFalse);
    expect(Directory(p.join(managedDir.path, ".opencode-runtime-staging")).existsSync(), isFalse);
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
      throwsA(isA<OpenCodeRuntimeInstallException>()),
    );
    expect(File(p.join(versionDir(), "opencode")).existsSync(), isFalse);
  });

  test("throws when extraction fails, surfacing the underlying reason", () async {
    await expectLater(
      install(build(extractSuccess: false)).drain<void>(),
      throwsA(
        isA<OpenCodeRuntimeInstallException>().having(
          (e) => e.message,
          "message",
          allOf(contains("failed to extract"), contains("Expand-Archive exited with code 1: boom")),
        ),
      ),
    );
  });

  test("maps a download failure to an install exception", () async {
    final service = build(downloadError: const DownloadException(kind: DownloadFailureKind.network, message: "offline"));
    await expectLater(install(service).drain<void>(), throwsA(isA<OpenCodeRuntimeInstallException>()));
  });

  test("aborts when the start-abort signal fires", () async {
    final controller = StartAbortController()..abort();
    await expectLater(
      install(build(), abort: controller.signal).drain<void>(),
      throwsA(isA<PluginStartAbortedException>()),
    );
  });
}
