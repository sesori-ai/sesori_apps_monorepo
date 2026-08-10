import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("ClaudeToolTracker", () {
    late ClaudeToolTracker tracker;

    setUp(() => tracker = ClaudeToolTracker());

    test("tracks a tool from pending through streamed input", () {
      final started = tracker.start(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 2,
        toolId: "toolu-1",
        name: "Read",
        input: const <String, Object?>{},
      );
      final delta = tracker.appendInput(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 2,
        partialJson: '{"file_',
      );
      tracker.appendInput(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 2,
        partialJson: 'path":"source.dart"}',
      );
      final stopped = tracker.stopInput(sessionId: "session-1", messageId: "message-1", blockIndex: 2);

      expect(started.state.status, PluginToolStatus.pending);
      expect(delta?.state.status, PluginToolStatus.running);
      expect(stopped?.state.status, PluginToolStatus.running);
      expect(stopped?.input, {"file_path": "source.dart"});
    });

    test("retains input deltas that arrive before their tool start", () {
      expect(
        tracker.appendInput(
          sessionId: "session-1",
          messageId: "message-1",
          blockIndex: 0,
          partialJson: '{"query":"value"}',
        ),
        isNull,
      );

      final started = tracker.start(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 0,
        toolId: "toolu-1",
        name: "Grep",
        input: const <String, Object?>{},
      );
      final stopped = tracker.stopInput(sessionId: "session-1", messageId: "message-1", blockIndex: 0);

      expect(started.state.status, PluginToolStatus.running);
      expect(stopped?.input, {"query": "value"});
    });

    test("complete blocks repair malformed partial input without completing the tool", () {
      tracker.start(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 0,
        toolId: "toolu-1",
        name: "Read",
        input: const <String, Object?>{},
      );
      tracker.appendInput(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 0,
        partialJson: "{malformed",
      );
      final complete = tracker.upsertCompleteBlock(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 0,
        toolId: "toolu-1",
        name: "Read",
        input: const {"file_path": "source.dart"},
      );
      final stopped = tracker.stopInput(sessionId: "session-1", messageId: "message-1", blockIndex: 0);

      expect(complete.state.status, PluginToolStatus.running);
      expect(stopped?.state.status, PluginToolStatus.running);
      expect(stopped?.input, {"file_path": "source.dart"});
    });

    test("malformed partial input does not fail or expose the tool card", () {
      tracker.start(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 0,
        toolId: "toolu-1",
        name: "Read",
        input: null,
      );
      tracker.appendInput(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 0,
        partialJson: "{private-path",
      );

      final stopped = tracker.stopInput(sessionId: "session-1", messageId: "message-1", blockIndex: 0);

      expect(stopped?.state.status, PluginToolStatus.running);
      expect(stopped?.input, isNull);
      expect(stopped.toString(), isNot(contains("private-path")));
    });

    test("matches successful and failed results without losing tool identity", () {
      tracker.start(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 0,
        toolId: "toolu-success",
        name: "Read",
        input: null,
      );
      tracker.start(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 1,
        toolId: "toolu-error",
        name: "Bash",
        input: null,
      );
      const attachment = PluginMessageAttachment.metadata(mime: "image/png", filename: null);

      final success = tracker.complete(
        sessionId: "session-1",
        toolId: "toolu-success",
        output: "done",
        isError: false,
        attachments: [attachment],
      );
      final failure = tracker.complete(
        sessionId: "session-1",
        toolId: "toolu-error",
        output: "failed",
        isError: true,
        attachments: const [],
      );

      expect(success?.messageId, "message-1");
      expect(success?.name, "Read");
      expect(success?.state.status, PluginToolStatus.completed);
      expect(success?.state.output, "done");
      expect(success?.state.attachments, [attachment]);
      expect(() => success!.state.attachments.add(attachment), throwsUnsupportedError);
      expect(failure?.state.status, PluginToolStatus.error);
      expect(failure?.state.output, isNull);
      expect(failure?.state.error, "failed");
    });

    test("ignores unmatched results instead of inventing an orphan tool", () {
      expect(
        tracker.complete(
          sessionId: "session-1",
          toolId: "unknown",
          output: "private output",
          isError: false,
          attachments: const [],
        ),
        isNull,
      );
    });

    test("terminal state does not regress after late stream updates", () {
      tracker.start(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 0,
        toolId: "toolu-1",
        name: "Read",
        input: null,
      );
      tracker.complete(
        sessionId: "session-1",
        toolId: "toolu-1",
        output: "done",
        isError: false,
        attachments: const [],
      );

      final lateDelta = tracker.appendInput(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 0,
        partialJson: "{}",
      );
      final lateStop = tracker.stopInput(sessionId: "session-1", messageId: "message-1", blockIndex: 0);

      expect(lateDelta?.state.status, PluginToolStatus.completed);
      expect(lateStop?.state.status, PluginToolStatus.completed);
    });

    test("retains the first terminal result when a duplicate arrives", () {
      tracker.start(
        sessionId: "session-1",
        messageId: "message-1",
        blockIndex: 0,
        toolId: "toolu-1",
        name: "Write",
        input: null,
      );
      final first = tracker.complete(
        sessionId: "session-1",
        toolId: "toolu-1",
        output: "first failure",
        isError: true,
        attachments: const [],
      );

      final duplicate = tracker.complete(
        sessionId: "session-1",
        toolId: "toolu-1",
        output: "later success",
        isError: false,
        attachments: const [PluginMessageAttachment.metadata(mime: "image/png", filename: null)],
      );

      expect(first?.sessionDiffRequired, isTrue);
      expect(duplicate?.sessionDiffRequired, isFalse);
      expect(duplicate?.state.status, PluginToolStatus.error);
      expect(duplicate?.state.error, "first failure");
      expect(duplicate?.state.output, isNull);
      expect(duplicate?.state.attachments, isEmpty);
    });

    test("edit-shaped results request one session diff", () {
      for (final name in ["Write", "Edit", "MultiEdit", "NotebookEdit"]) {
        tracker.start(
          sessionId: name,
          messageId: "message-1",
          blockIndex: 0,
          toolId: "toolu-1",
          name: name,
          input: null,
        );

        final first = tracker.complete(
          sessionId: name,
          toolId: "toolu-1",
          output: name == "Edit" ? "failed" : "done",
          isError: name == "Edit",
          attachments: const [],
        );
        final duplicate = tracker.complete(
          sessionId: name,
          toolId: "toolu-1",
          output: "done again",
          isError: false,
          attachments: const [],
        );

        expect(first?.sessionDiffRequired, isTrue, reason: name);
        expect(duplicate?.sessionDiffRequired, isFalse, reason: name);
      }
    });

    test("non-mutating tools do not request a session diff", () {
      for (final name in ["Read", "Glob", "Grep", "Bash"]) {
        tracker.start(
          sessionId: name,
          messageId: "message-1",
          blockIndex: 0,
          toolId: "toolu-1",
          name: name,
          input: null,
        );

        final result = tracker.complete(
          sessionId: name,
          toolId: "toolu-1",
          output: "done",
          isError: false,
          attachments: const [],
        );

        expect(result?.sessionDiffRequired, isFalse, reason: name);
      }
    });

    test("keeps concurrent blocks and sessions isolated", () {
      for (final (sessionId, blockIndex, toolId) in [
        ("session-1", 0, "toolu-1"),
        ("session-1", 1, "toolu-2"),
        ("session-2", 0, "toolu-1"),
      ]) {
        tracker.start(
          sessionId: sessionId,
          messageId: "message-1",
          blockIndex: blockIndex,
          toolId: toolId,
          name: "Read",
          input: null,
        );
        tracker.appendInput(
          sessionId: sessionId,
          messageId: "message-1",
          blockIndex: blockIndex,
          partialJson: '{"value":"$sessionId-$toolId"}',
        );
      }

      expect(
        tracker.stopInput(sessionId: "session-1", messageId: "message-1", blockIndex: 0)?.input,
        {"value": "session-1-toolu-1"},
      );
      expect(
        tracker.stopInput(sessionId: "session-1", messageId: "message-1", blockIndex: 1)?.input,
        {"value": "session-1-toolu-2"},
      );
      expect(
        tracker.stopInput(sessionId: "session-2", messageId: "message-1", blockIndex: 0)?.input,
        {"value": "session-2-toolu-1"},
      );
    });

    test("turn and session cleanup remove only the exact session", () {
      for (final sessionId in ["session", "session-child"]) {
        tracker.start(
          sessionId: sessionId,
          messageId: "message-1",
          blockIndex: 0,
          toolId: "toolu-1",
          name: "Read",
          input: null,
        );
      }

      tracker.beginTurn(sessionId: "session");
      expect(_complete(tracker, sessionId: "session"), isNull);
      expect(_complete(tracker, sessionId: "session-child"), isNotNull);

      tracker.forgetSession(sessionId: "session-child");
      expect(_complete(tracker, sessionId: "session-child"), isNull);
    });
  });
}

ClaudeTrackedTool? _complete(ClaudeToolTracker tracker, {required String sessionId}) => tracker.complete(
  sessionId: sessionId,
  toolId: "toolu-1",
  output: "done",
  isError: false,
  attachments: const [],
);
