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
        model: null,
        thinkingLevel: null,
        environment: const {},
      );

      expect(spec.arguments, ["--mode", "rpc", "--approve", "--session-id", "sesori.session-1"]);
    });

    test("starts a session with the requested model and thinking level", () {
      final spec = PiLaunchSpec(
        binaryPath: "pi",
        workingDirectory: "/tmp/project",
        launch: PiNewSession(sessionId: "selected-session"),
        model: (providerID: "openai-codex", modelID: "gpt-5.6-sol"),
        thinkingLevel: "max",
        environment: const {},
      );

      expect(spec.arguments, [
        "--mode",
        "rpc",
        "--approve",
        "--session-id",
        "selected-session",
        "--provider",
        "openai-codex",
        "--model",
        "gpt-5.6-sol",
        "--thinking",
        "max",
      ]);
    });

    test("adds one native extension without disabling discovered user extensions", () {
      final spec = PiLaunchSpec(
        binaryPath: "pi",
        workingDirectory: "/tmp/project",
        launch: PiNewSession(sessionId: "session-1"),
        model: null,
        thinkingLevel: null,
        environment: const {},
        extensionPath: "/private/device-canvas.ts",
      );

      expect(spec.arguments, [
        "--mode",
        "rpc",
        "--approve",
        "--session-id",
        "session-1",
        "--extension",
        "/private/device-canvas.ts",
      ]);
      expect(spec.arguments, isNot(contains("--no-extensions")));
      expect(
        () => PiLaunchSpec(
          binaryPath: "pi",
          workingDirectory: "/tmp/project",
          launch: PiNewSession(sessionId: "session-1"),
          model: null,
          thinkingLevel: null,
          environment: const {},
          extensionPath: "relative.ts",
        ),
        throwsArgumentError,
      );
    });

    test("builds the exact parent-fork RPC argument vector", () {
      final parentPath = Platform.isWindows ? r"C:\sessions\parent.jsonl" : "/sessions/parent.jsonl";
      final spec = PiLaunchSpec(
        binaryPath: "pi",
        workingDirectory: "/tmp/project",
        launch: PiForkedSession(sessionId: "child", parentSessionPath: parentPath),
        model: null,
        thinkingLevel: null,
        environment: const {},
      );

      expect(spec.arguments, [
        "--mode",
        "rpc",
        "--approve",
        "--fork",
        parentPath,
        "--session-id",
        "child",
      ]);
      expect(
        () => PiForkedSession(sessionId: "child", parentSessionPath: "sessions/parent.jsonl"),
        throwsArgumentError,
      );
    });

    test("builds the exact no-session probe argument vector", () {
      final spec = PiLaunchSpec(
        binaryPath: "pi",
        workingDirectory: "/tmp/project",
        launch: const PiNoSession(),
        model: null,
        thinkingLevel: null,
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
        model: null,
        thinkingLevel: null,
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
        model: null,
        thinkingLevel: null,
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
        model: null,
        thinkingLevel: null,
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
          model: null,
          thinkingLevel: null,
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
