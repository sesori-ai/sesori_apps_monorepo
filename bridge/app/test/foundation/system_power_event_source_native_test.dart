import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/foundation/macos_system_power_observer_api.dart";
import "package:test/test.dart";

void main() {
  test("bundled native macOS power observer starts and disposes without sleeping", () async {
    if (!Platform.isMacOS) return;
    final api = MacosSystemPowerObserverApi();
    final startup = Completer<({int event, int errorCode})>();
    addTearDown(api.stop);
    api.start(
      callback: (event, errorCode) {
        if ((event == 0 || event == 3) && !startup.isCompleted) {
          startup.complete((event: event, errorCode: errorCode));
        }
      },
    );
    expect(await startup.future.timeout(const Duration(seconds: 10)), (event: 0, errorCode: 0));
  });

  test("native observer disposal before run-loop startup does not hang", () async {
    if (!Platform.isMacOS) return;
    final directory = await Directory.systemTemp.createTemp("sesori-power-observer-test-");
    addTearDown(() => directory.delete(recursive: true));
    final executable = "${directory.path}/stop-before-run";
    final compilation = await Process.run("clang", [
      "-fblocks",
      "-framework",
      "CoreFoundation",
      "-framework",
      "IOKit",
      "test/native/macos_power_observer_stop_before_run.c",
      "-o",
      executable,
    ]);
    expect(compilation.exitCode, 0, reason: "${compilation.stderr}");

    // A stuck synchronous native join also blocks Dart's isolate. Exercise it
    // in a child process so a regression can be terminated rather than hanging
    // the test runner itself.
    final process = await Process.start(executable, const []);
    final stdout = process.stdout.transform(const SystemEncoding().decoder).join();
    final stderr = process.stderr.transform(const SystemEncoding().decoder).join();
    addTearDown(() async {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    });
    final exitCode = await process.exitCode.timeout(const Duration(seconds: 10));
    expect(exitCode, 0, reason: await stderr);
    expect(await stdout, contains("Observer stopped after disposal preceded run-loop startup"));
  });
}
