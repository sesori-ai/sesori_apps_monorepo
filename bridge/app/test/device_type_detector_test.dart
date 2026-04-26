import "dart:io";

import "package:sesori_bridge/src/bridge/foundation/device_type_detector.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
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
        platformChecker: _FakePlatformChecker(isMacOS: true),
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
        platformChecker: _FakePlatformChecker(isMacOS: true),
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
        platformChecker: _FakePlatformChecker(isWindows: true),
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
        platformChecker: _FakePlatformChecker(isWindows: true),
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
        platformChecker: _FakePlatformChecker(isMacOS: true),
      );

      final isLaptop = await detector.isLaptop();
      expect(isLaptop, isFalse);
    });
  });
}

class _FakeResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  _FakeResult({
    required this.exitCode,
    this.stdout = "",
    this.stderr = "",
  });
}

class _FakeProcessRunner implements ProcessRunner {
  final Map<String, _FakeResult> results;

  _FakeProcessRunner({required this.results});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
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
}

class _FakePlatformChecker implements PlatformChecker {
  final bool _isMacOS;
  final bool _isWindows;
  final bool _isLinux;

  _FakePlatformChecker({
    bool isMacOS = false,
    bool isWindows = false,
    bool isLinux = false,
  }) : _isMacOS = isMacOS,
       _isWindows = isWindows,
       _isLinux = isLinux;

  @override
  bool get isMacOS => _isMacOS;

  @override
  bool get isWindows => _isWindows;

  @override
  bool get isLinux => _isLinux;
}
