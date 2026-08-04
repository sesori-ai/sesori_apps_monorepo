import "package:claude_plugin/claude_plugin.dart";
import "package:test/test.dart";

void main() {
  group("ClaudeLaunchSpec", () {
    ClaudeLaunchSpec specFor(
      ClaudeSessionLaunch launch, {
      String? model,
      ClaudeEffortLevel? effort,
      ClaudePermissionMode? permissionMode,
    }) {
      return ClaudeLaunchSpec(
        binaryPath: "claude",
        launch: launch,
        model: model,
        effort: effort,
        permissionMode: permissionMode,
      );
    }

    test("always requests stream-json in print mode with partial messages", () {
      final arguments = specFor(const ClaudeNewSession(sessionId: "s-1")).arguments;

      // `--print` is what makes the stream-json formats legal at all.
      expect(arguments, containsAllInOrder(["-p", "--input-format", "stream-json"]));
      expect(arguments, containsAllInOrder(["--output-format", "stream-json"]));
      expect(arguments, contains("--verbose"));
      expect(arguments, contains("--include-partial-messages"));
    });

    test("always routes permission asks over stdio", () {
      // Regression guard for the protocol's sharpest edge: without this flag
      // the CLI silently auto-denies every permission-gated tool instead of
      // asking, and the turn still reports success.
      for (final launch in [
        const ClaudeNewSession(sessionId: "s-1"),
        const ClaudeResumedSession(sessionId: "s-1"),
      ]) {
        expect(
          specFor(launch).arguments,
          containsAllInOrder(["--permission-prompt-tool", "stdio"]),
          reason: "$launch must still route permission asks over stdio",
        );
      }
    });

    test("binds a pre-generated id for a new session", () {
      final arguments = specFor(const ClaudeNewSession(sessionId: "new-session")).arguments;

      expect(arguments, containsAllInOrder(["--session-id", "new-session"]));
      expect(arguments, isNot(contains("--resume")));
    });

    test("resumes an existing session by id", () {
      final arguments = specFor(const ClaudeResumedSession(sessionId: "old-session")).arguments;

      expect(arguments, containsAllInOrder(["--resume", "old-session"]));
      expect(arguments, isNot(contains("--session-id")));
    });

    test("omits optional selections that were not made", () {
      final arguments = specFor(const ClaudeNewSession(sessionId: "s-1")).arguments;

      expect(arguments, isNot(contains("--model")));
      expect(arguments, isNot(contains("--effort")));
      expect(arguments, isNot(contains("--permission-mode")));
    });

    test("passes model, effort, and permission mode when selected", () {
      final arguments = specFor(
        const ClaudeNewSession(sessionId: "s-1"),
        model: "opus[1m]",
        effort: ClaudeEffortLevel.xhigh,
        permissionMode: ClaudePermissionMode.plan,
      ).arguments;

      expect(arguments, containsAllInOrder(["--model", "opus[1m]"]));
      expect(arguments, containsAllInOrder(["--effort", "xhigh"]));
      expect(arguments, containsAllInOrder(["--permission-mode", "plan"]));
    });

    test("spells the standard mode the way the command line expects", () {
      final arguments = specFor(
        const ClaudeNewSession(sessionId: "s-1"),
        permissionMode: ClaudePermissionMode.standard,
      ).arguments;

      // The CLI flag calls it `manual`; only the control protocol says
      // `default`. Passing the control spelling here is rejected.
      expect(arguments, containsAllInOrder(["--permission-mode", "manual"]));
      expect(arguments, isNot(contains("default")));
    });
  });

  group("ClaudePermissionMode", () {
    test("keeps the command line and control spellings apart", () {
      expect(ClaudePermissionMode.standard.cliValue, "manual");
      expect(ClaudePermissionMode.standard.controlValue, "default");
    });

    test("parses either spelling of the same mode", () {
      expect(ClaudePermissionMode.tryParse("manual"), ClaudePermissionMode.standard);
      expect(ClaudePermissionMode.tryParse("default"), ClaudePermissionMode.standard);
      expect(ClaudePermissionMode.tryParse(" plan "), ClaudePermissionMode.plan);
      expect(ClaudePermissionMode.tryParse("acceptEdits"), ClaudePermissionMode.acceptEdits);
    });

    test("fails soft on a mode this build does not know", () {
      expect(ClaudePermissionMode.tryParse("someFutureMode"), isNull);
      expect(ClaudePermissionMode.tryParse(""), isNull);
      expect(ClaudePermissionMode.tryParse(null), isNull);
    });
  });

  group("ClaudeEffortLevel", () {
    test("round-trips every level the CLI accepts", () {
      for (final level in ClaudeEffortLevel.values) {
        expect(ClaudeEffortLevel.tryParse(level.wireValue), level);
      }
    });

    test("fails soft on an unknown level", () {
      expect(ClaudeEffortLevel.tryParse("extreme"), isNull);
      expect(ClaudeEffortLevel.tryParse(null), isNull);
    });
  });
}
