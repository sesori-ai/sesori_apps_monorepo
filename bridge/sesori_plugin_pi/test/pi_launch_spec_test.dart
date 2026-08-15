import "dart:io";

import "package:pi_plugin/pi_plugin.dart";
import "package:test/test.dart";

void main() {
  group("PiLaunchSpec", () {
    test("builds the exact new-session RPC argument vector", () {
      final spec = PiLaunchSpec(
        binaryPath: "pi",
        workingDirectory: "/tmp/project",
        launch: PiNewSession(sessionId: "sesori.session-1"),
        environment: const {},
      );

      expect(spec.arguments, ["--mode", "rpc", "--approve", "--session-id", "sesori.session-1"]);
    });

    test("builds the exact no-session probe argument vector", () {
      final spec = PiLaunchSpec(
        binaryPath: "pi",
        workingDirectory: "/tmp/project",
        launch: const PiNoSession(),
        environment: const {},
      );

      expect(spec.arguments, ["--mode", "rpc", "--no-session", "--approve"]);
    });

    test("resumes only by absolute path", () {
      final absolutePath = Platform.isWindows ? r"C:\sessions\session.jsonl" : "/sessions/session.jsonl";
      final spec = PiLaunchSpec(
        binaryPath: "pi",
        workingDirectory: "/tmp/project",
        launch: PiResumedSession(sessionPath: absolutePath),
        environment: const {},
      );

      expect(spec.arguments, ["--mode", "rpc", "--approve", "--session", absolutePath]);
      expect(() => PiResumedSession(sessionPath: "sessions/session.jsonl"), throwsArgumentError);
    });

    test("preserves a resolved native Windows entry path", () {
      final spec = PiLaunchSpec(
        binaryPath: r"C:\managed-pi\pi.exe",
        workingDirectory: r"C:\project",
        launch: PiNewSession(sessionId: "session-1"),
        environment: const {},
      );

      expect(spec.binaryPath, r"C:\managed-pi\pi.exe");
    });

    test("preserves overrides and enforces supervised version policy", () {
      final environment = {"ANTHROPIC_API_KEY": "test", "PI_SKIP_VERSION_CHECK": "0"};
      final spec = PiLaunchSpec(
        binaryPath: "pi",
        workingDirectory: "/tmp/project",
        launch: PiNewSession(sessionId: "session-1"),
        environment: environment,
      );

      environment["ANTHROPIC_API_KEY"] = "changed";
      expect(spec.environment, {"ANTHROPIC_API_KEY": "test", "PI_SKIP_VERSION_CHECK": "1"});
      expect(() => spec.environment["NEW"] = "value", throwsUnsupportedError);
    });

    test("rejects HOME overrides", () {
      const secret = "provider-secret";
      expect(
        () => PiLaunchSpec(
          binaryPath: "pi",
          workingDirectory: "/tmp/project",
          launch: PiNewSession(sessionId: "session-1"),
          environment: const {"HOME": "/tmp/isolated", "ANTHROPIC_API_KEY": secret},
        ),
        throwsA(
          isA<ArgumentError>().having((error) => error.toString(), "message", isNot(contains(secret))),
        ),
      );
    });
  });

  group("PiSessionLaunch", () {
    test("accepts Pi's documented session ID grammar", () {
      for (final id in ["a", "A0", "session.id", "session_id", "session-id"]) {
        expect(PiNewSession(sessionId: id).sessionId, id);
      }
    });

    test("rejects session IDs Pi would refuse", () {
      for (final id in ["", "-session", "session-", ".session", "session.", "session id"]) {
        expect(() => PiNewSession(sessionId: id), throwsArgumentError, reason: id);
      }
    });
  });
}
