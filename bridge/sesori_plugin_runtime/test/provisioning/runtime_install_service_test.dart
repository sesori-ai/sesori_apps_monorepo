import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
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
  Future<bool> extract({required String archivePath, required String stagingPath, required ArchiveFormat format}) async {
    if (!success) {
      return false;
    }
    Directory(stagingPath).createSync(recursive: true);
    File(p.join(stagingPath, "opencode")).writeAsStringSync("BINARY");
    return true;
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

const _asset = RuntimeAsset(
  assetName: "opencode-test.zip",
  format: ArchiveFormat.zip,
  sha256: "abc123",
  archiveBinaryName: "opencode",
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
    _FakeCommandExecutor? cmd,
  }) {
    return RuntimeInstallService(
      downloadClient: _FakeDownloadClient(exception: downloadError),
      checksumValidator: _FakeChecksumValidator(valid: checksumValid),
      archiveExtractor: _FakeArchiveExtractor(success: extractSuccess),
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
    // The download + staging scratch are cleaned up.
    expect(File(p.join(managedDir.path, ".sesori-runtime-download")).existsSync(), isFalse);
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

  test("throws when extraction fails", () async {
    await expectLater(
      install(build(extractSuccess: false)).drain<void>(),
      throwsA(isA<RuntimeInstallException>()),
    );
  });

  test("maps a download failure to an install exception", () async {
    final service = build(downloadError: const DownloadException(kind: DownloadFailureKind.network, message: "offline"));
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
