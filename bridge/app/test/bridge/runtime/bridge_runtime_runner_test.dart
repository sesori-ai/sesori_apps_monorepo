import "dart:io";

import "package:sesori_bridge/src/runtime/bridge_runtime_runner.dart";
import "package:sesori_shared/sesori_shared.dart" show BridgeSupervisedExitCode;
import "package:test/test.dart";

import "../../helpers/fake_process_runner.dart";

void main() {
  group("BridgeRuntimeRunner.isLoopbackControlUrl", () {
    test("accepts ws/wss on loopback hosts", () {
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("ws://127.0.0.1:54321/control")), isTrue);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("wss://localhost:9/ctrl")), isTrue);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("ws://[::1]:8080")), isTrue);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("WS://LOCALHOST:9")), isTrue);
    });

    test("rejects non-loopback hosts", () {
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("ws://evil.example.com:80/control")), isFalse);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("ws://10.0.0.5:9")), isFalse);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("wss://0.0.0.0:9")), isFalse);
    });

    test("rejects non-ws schemes even on loopback", () {
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("http://127.0.0.1:9")), isFalse);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("https://localhost:9")), isFalse);
    });
  });

  group("BridgeRuntimeRunner.resolveSupervisedTokenUnavailableExit", () {
    test("uses auth-required when no lifecycle outcome exists", () {
      expect(
        BridgeRuntimeRunner.resolveSupervisedTokenUnavailableExit(requestedExit: null),
        BridgeSupervisedExitCode.authRequired,
      );
    });

    test("preserves a lifecycle outcome selected before token cancellation", () {
      for (final BridgeSupervisedExitCode requestedExit in <BridgeSupervisedExitCode>[
        BridgeSupervisedExitCode.cleanStop,
        BridgeSupervisedExitCode.controlChannelLost,
        BridgeSupervisedExitCode.restart,
      ]) {
        expect(
          BridgeRuntimeRunner.resolveSupervisedTokenUnavailableExit(requestedExit: requestedExit),
          requestedExit,
        );
      }
    });
  });

  group("BridgeRuntimeRunner.shouldRunAppOnboarding", () {
    test("runs for an interactive standalone start even without a plugin", () {
      expect(
        BridgeRuntimeRunner.shouldRunAppOnboarding(
          isSupervised: false,
          isInteractive: true,
        ),
        isTrue,
      );
    });

    test("skips supervised and noninteractive starts", () {
      expect(
        BridgeRuntimeRunner.shouldRunAppOnboarding(
          isSupervised: true,
          isInteractive: true,
        ),
        isFalse,
      );
      expect(
        BridgeRuntimeRunner.shouldRunAppOnboarding(
          isSupervised: false,
          isInteractive: false,
        ),
        isFalse,
      );
    });
  });

  group("BridgeRuntimeRunner.resolveLocalMachineName", () {
    test("uses the stable macOS LocalHostName instead of a numeric hostname", () async {
      final runner = RecordingProcessRunner(
        result: ProcessResult(1, 0, "Alexs-MB-2025\n", ""),
      );

      final name = await BridgeRuntimeRunner.resolveLocalMachineName(
        isMacOS: true,
        processRunner: runner,
        localHostname: "192.168.1.170",
      );

      expect(name, "Alexs-MB-2025");
      expect(runner.executable, "/usr/sbin/scutil");
      expect(runner.arguments, ["--get", "LocalHostName"]);
    });

    test("uses a non-numeric macOS hostname when LocalHostName is unavailable", () async {
      final name = await BridgeRuntimeRunner.resolveLocalMachineName(
        isMacOS: true,
        processRunner: RecordingProcessRunner(
          result: ProcessResult(1, 1, "", "No such key"),
        ),
        localHostname: "dev-laptop.local",
      );

      expect(name, "dev-laptop.local");
    });

    test("replaces a numeric macOS fallback hostname with one canonical name", () async {
      final name = await BridgeRuntimeRunner.resolveLocalMachineName(
        isMacOS: true,
        processRunner: RecordingProcessRunner(
          result: ProcessResult(1, 1, "", "No such key"),
        ),
        localHostname: "192.168.1.170",
      );

      expect(name, "sesori-bridge");
    });

    test("keeps the platform hostname without invoking scutil elsewhere", () async {
      final runner = RecordingProcessRunner(
        result: ProcessResult(1, 0, "unused", ""),
      );

      final name = await BridgeRuntimeRunner.resolveLocalMachineName(
        isMacOS: false,
        processRunner: runner,
        localHostname: "linux-workstation",
      );

      expect(name, "linux-workstation");
      expect(runner.executable, isNull);
    });
  });
}
