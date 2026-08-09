import "package:claude_plugin/claude_plugin.dart";
import "package:test/test.dart";

// Real UUIDs: the launch contract rejects anything else.
const String _newSessionId = "11111111-2222-4333-8444-555555555555";
const String _oldSessionId = "66666666-7777-4888-8999-aaaaaaaaaaaa";

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
        workingDirectory: "/tmp/project",
        launch: launch,
        model: model,
        effort: effort,
        permissionMode: permissionMode,
      );
    }

    test("always requests stream-json in print mode with partial messages", () {
      final arguments = specFor(ClaudeNewSession(sessionId: _newSessionId)).arguments;

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
        ClaudeNewSession(sessionId: _newSessionId),
        ClaudeResumedSession(sessionId: _oldSessionId),
      ]) {
        expect(
          specFor(launch).arguments,
          containsAllInOrder(["--permission-prompt-tool", "stdio"]),
          reason: "$launch must still route permission asks over stdio",
        );
      }
    });

    test("binds a pre-generated id for a new session", () {
      final arguments = specFor(ClaudeNewSession(sessionId: _newSessionId)).arguments;

      // Single-token form, matching the SDK's own argument builder.
      expect(arguments, contains("--session-id=$_newSessionId"));
      expect(arguments.where((argument) => argument.startsWith("--resume")), isEmpty);
    });

    test("resumes an existing session by id", () {
      final arguments = specFor(ClaudeResumedSession(sessionId: _oldSessionId)).arguments;

      expect(arguments, contains("--resume=$_oldSessionId"));
      expect(arguments.where((argument) => argument.startsWith("--session-id")), isEmpty);
    });

    test("never splits an id flag into two tokens", () {
      // The SDK writes `--session-id=<id>` and `--resume=<id>`. The CLI accepts
      // the split form too, so only an explicit assertion keeps them in parity.
      for (final launch in [
        ClaudeNewSession(sessionId: _newSessionId),
        ClaudeResumedSession(sessionId: _oldSessionId),
      ]) {
        final arguments = specFor(launch).arguments;
        expect(arguments, isNot(contains("--session-id")));
        expect(arguments, isNot(contains("--resume")));
        expect(arguments, isNot(contains(_newSessionId)));
        expect(arguments, isNot(contains(_oldSessionId)));
      }
    });

    test("omits optional selections that were not made", () {
      final arguments = specFor(ClaudeNewSession(sessionId: _newSessionId)).arguments;

      expect(arguments, isNot(contains("--model")));
      expect(arguments, isNot(contains("--effort")));
      expect(arguments, isNot(contains("--permission-mode")));
    });

    test("passes model, effort, and permission mode when selected", () {
      final arguments = specFor(
        ClaudeNewSession(sessionId: _newSessionId),
        model: "opus[1m]",
        effort: ClaudeEffortLevel.xhigh,
        permissionMode: ClaudePermissionMode.plan,
      ).arguments;

      expect(arguments, containsAllInOrder(["--model", "opus[1m]"]));
      expect(arguments, containsAllInOrder(["--effort", "xhigh"]));
      expect(arguments, containsAllInOrder(["--permission-mode", "plan"]));
    });

    test("rejects a HOME override", () {
      expect(
        () => ClaudeLaunchSpec(
          binaryPath: "claude",
          workingDirectory: "/tmp/project",
          launch: ClaudeNewSession(sessionId: _newSessionId),
          model: null,
          effort: null,
          permissionMode: null,
          environment: const {"HOME": "/tmp/test-home"},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test("spells the standard mode the way the command line expects", () {
      final arguments = specFor(
        ClaudeNewSession(sessionId: _newSessionId),
        permissionMode: ClaudePermissionMode.standard,
      ).arguments;

      // The CLI flag calls it `manual`; only the control protocol says
      // `default`. Passing the control spelling here is rejected.
      expect(arguments, containsAllInOrder(["--permission-mode", "manual"]));
      expect(arguments, isNot(contains("default")));
    });
  });

  group("ClaudeSessionLaunch", () {
    test("rejects a session id the CLI would refuse", () {
      // Failing here names the problem; failing at spawn surfaces it as an
      // opaque CLI startup error on a session the user just tried to open.
      for (final invalid in ["", "s-1", "not-a-uuid", "11111111-2222-4333-8444-55555555555"]) {
        expect(
          () => ClaudeNewSession(sessionId: invalid),
          throwsA(isA<ArgumentError>()),
          reason: "$invalid is not a UUID",
        );
        expect(() => ClaudeResumedSession(sessionId: invalid), throwsA(isA<ArgumentError>()));
      }
    });

    test("accepts a UUID in either case", () {
      expect(ClaudeNewSession(sessionId: _newSessionId).sessionId, _newSessionId);
      expect(
        ClaudeResumedSession(sessionId: _newSessionId.toUpperCase()).sessionId,
        _newSessionId.toUpperCase(),
      );
    });
  });

  group("ClaudePermissionMode", () {
    test("keeps the command line and control spellings apart", () {
      expect(ClaudePermissionMode.standard.cliValue, "manual");
      expect(ClaudePermissionMode.standard.controlValue, "default");
    });

    test("parses both spellings of every mode", () {
      // Table-driven over `values` so a new mode cannot ship untested and a
      // typo in a wire value fails here rather than at launch.
      for (final mode in ClaudePermissionMode.values) {
        expect(ClaudePermissionMode.tryParse(mode.cliValue), mode, reason: "cli spelling of $mode");
        expect(ClaudePermissionMode.tryParse(mode.controlValue), mode, reason: "control spelling of $mode");
      }
    });

    test("gives every mode a distinct pair of wire values", () {
      // Two modes sharing a spelling would make parsing ambiguous and silently
      // pick whichever is declared first.
      expect(
        ClaudePermissionMode.values.map((mode) => mode.cliValue).toSet(),
        hasLength(ClaudePermissionMode.values.length),
      );
      expect(
        ClaudePermissionMode.values.map((mode) => mode.controlValue).toSet(),
        hasLength(ClaudePermissionMode.values.length),
      );
    });

    test("tolerates surrounding whitespace", () {
      expect(ClaudePermissionMode.tryParse(" plan "), ClaudePermissionMode.plan);
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
