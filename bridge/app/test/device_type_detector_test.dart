import "dart:io";

import "package:sesori_bridge/src/foundation/device_type_detector.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:test/test.dart";

void main() {
  group("DeviceTypeDetector", () {
    test("detects macOS laptop when hw.model contains MacBook", () async {
      final detector = DeviceTypeDetector(
        processRunner: _FakeProcessRunner(
          results: <String, _FakeResult>{
            "sysctl": _FakeResult(
              exitCode: 0,
              stdout: "MacBookPro18,1\n",
            ),
          },
        ),
        platform: PlatformOs.macos,
      );

      final isLaptop = await detector.isLaptop();
      expect(isLaptop, isTrue);
    });

    test("detects macOS desktop when hw.model does not contain MacBook", () async {
      final detector = DeviceTypeDetector(
        processRunner: _FakeProcessRunner(
          results: <String, _FakeResult>{
            "sysctl": _FakeResult(
              exitCode: 0,
              stdout: "Macmini9,1\n",
            ),
          },
        ),
        platform: PlatformOs.macos,
      );

      final isLaptop = await detector.isLaptop();
      expect(isLaptop, isFalse);
    });

    test("detects Windows laptop when battery is present", () async {
      final detector = DeviceTypeDetector(
        processRunner: _FakeProcessRunner(
          results: <String, _FakeResult>{
            "powershell.exe": _FakeResult(
              exitCode: 0,
              stdout: "1\n",
            ),
          },
        ),
        platform: PlatformOs.windows,
      );

      final isLaptop = await detector.isLaptop();
      expect(isLaptop, isTrue);
    });

    test("detects Windows desktop when no battery is present", () async {
      final detector = DeviceTypeDetector(
        processRunner: _FakeProcessRunner(
          results: <String, _FakeResult>{
            "powershell.exe": _FakeResult(
              exitCode: 0,
              stdout: "0\n",
            ),
          },
        ),
        platform: PlatformOs.windows,
      );

      final isLaptop = await detector.isLaptop();
      expect(isLaptop, isFalse);
    });

    test("returns false on error", () async {
      final detector = DeviceTypeDetector(
        processRunner: _FakeProcessRunner(
          results: <String, _FakeResult>{
            "sysctl": _FakeResult(
              exitCode: 1,
              stdout: "",
              stderr: "error",
            ),
          },
        ),
        platform: PlatformOs.macos,
      );

      final isLaptop = await detector.isLaptop();
      expect(isLaptop, isFalse);
    });

    test("caches result across multiple calls", () async {
      final processRunner = _FakeProcessRunner(
        results: <String, _FakeResult>{
          "sysctl": _FakeResult(
            exitCode: 0,
            stdout: "MacBookPro18,1\n",
          ),
        },
      );
      final detector = DeviceTypeDetector(
        processRunner: processRunner,
        platform: PlatformOs.macos,
      );

      final first = await detector.isLaptop();
      final second = await detector.isLaptop();

      expect(first, isTrue);
      expect(second, isTrue);
      expect(processRunner.callCount("sysctl"), equals(1));
    });

    test("detects Linux laptop when battery entries exist", () async {
      final tempDir = await Directory.systemTemp.createTemp(
        "device_type_detector_test_",
      );
      await File("${tempDir.path}/BAT0").create();
      await File("${tempDir.path}/AC").create();

      final detector = DeviceTypeDetector(
        processRunner: _FakeProcessRunner(results: const <String, _FakeResult>{}),
        platform: PlatformOs.linux,
        linuxPowerSupplyPath: tempDir.path,
      );

      final isLaptop = await detector.isLaptop();
      expect(isLaptop, isTrue);

      await tempDir.delete(recursive: true);
    });

    test("detects Linux desktop when no battery entries exist", () async {
      final tempDir = await Directory.systemTemp.createTemp(
        "device_type_detector_test_",
      );
      await File("${tempDir.path}/AC").create();

      final detector = DeviceTypeDetector(
        processRunner: _FakeProcessRunner(results: const <String, _FakeResult>{}),
        platform: PlatformOs.linux,
        linuxPowerSupplyPath: tempDir.path,
      );

      final isLaptop = await detector.isLaptop();
      expect(isLaptop, isFalse);

      await tempDir.delete(recursive: true);
    });

    test("returns false for Linux when power supply dir does not exist", () async {
      final detector = DeviceTypeDetector(
        processRunner: _FakeProcessRunner(results: const <String, _FakeResult>{}),
        platform: PlatformOs.linux,
        linuxPowerSupplyPath: "/nonexistent/path/",
      );

      final isLaptop = await detector.isLaptop();
      expect(isLaptop, isFalse);
    });
  });
}

class _FakeResult({
  required final int exitCode,
  final String stdout = "",
  final String stderr = "",
});

class _FakeProcessRunner({required final Map<String, _FakeResult> results}) implements ProcessRunner {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  final Map<String, int> _callCounts = <String, int>{};

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _callCounts[executable] = (_callCounts[executable] ?? 0) + 1;
    final result = results[executable];
    if (result == null) {
      throw ProcessException(executable, arguments, "command not found");
    }
    return ProcessResult(
      12345,
      result.exitCode,
      result.stdout,
      result.stderr,
    );
  }

  int callCount(String executable) => _callCounts[executable] ?? 0;
}
