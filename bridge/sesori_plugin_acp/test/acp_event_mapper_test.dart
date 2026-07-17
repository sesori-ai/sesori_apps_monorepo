import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

/// Asserts the mapper emits sesori-schema payloads — message envelopes must
/// round-trip through `Message.fromJson`, exactly like the codex mapper.
void main() {
  group("AcpEventMapper", () {
    late AcpEventMapper mapper;

    setUp(() {
      mapper = AcpEventMapper(launchDirectory: "/repo", agentId: "cursor", pluginId: "cursor")
        ..currentModelId = "gpt-5.4"
        ..currentProviderId = "cursor";
    });

    AcpNotificationRecord update(Map<String, dynamic> body) => mapAcpNotificationForTest(
      AcpNotification(
        method: "session/update",
        params: {"sessionId": "s1", "update": body},
      ),
    );

    test("agent_message_chunk emits envelope + part + delta on first chunk", () {
      mapper.beginTurn("s1");
      final events = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "Hello"},
        }),
      );

      final updated = events.whereType<BridgeSseMessageUpdated>().single;
      final message = shared.Message.fromJson(updated.info);
      expect(message, isA<shared.MessageAssistant>());

      expect(events.whereType<BridgeSseMessagePartUpdated>(), hasLength(1));
      final delta = events.whereType<BridgeSseMessagePartDelta>().single;
      expect(delta.delta, "Hello");
      expect(delta.field, "text");
    });

    test("subsequent chunks emit only a delta on the same part", () {
      mapper.beginTurn("s1");
      mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "Hel"},
        }),
      );
      final second = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "lo"},
        }),
      );
      expect(second.whereType<BridgeSseMessageUpdated>(), isEmpty);
      expect(second.whereType<BridgeSseMessagePartDelta>().single.delta, "lo");
    });

    test("agent_thought_chunk maps to a reasoning part", () {
      mapper.beginTurn("s1");
      final events = mapper.map(
        update({
          "sessionUpdate": "agent_thought_chunk",
          "content": {"type": "text", "text": "thinking"},
        }),
      );
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.type, PluginMessagePartType.reasoning);
    });

    test("an accepted prompt maps to one canonical live user message", () {
      final events = mapper.mapSentPrompt(
        sessionId: "s1",
        parts: [
          const PluginPromptPart.text(text: "Hello"),
          const PluginPromptPart.text(text: "Cursor"),
        ],
      );

      final message = shared.Message.fromJson(
        events.whereType<BridgeSseMessageUpdated>().single.info,
      );
      expect(message, isA<shared.MessageUser>());
      expect(
        events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part.text),
        ["Hello", "Cursor"],
      );
    });

    test("a live agent user echo is dropped", () {
      mapper.mapSentPrompt(
        sessionId: "s1",
        parts: [const PluginPromptPart.text(text: "Hello")],
      );

      final events = mapper.map(
        update({
          "sessionUpdate": "user_message_chunk",
          "content": {"type": "text", "text": "Hello"},
        }),
      );

      expect(events, isEmpty);
    });

    test("id-less assistant text after a tool opens a later envelope", () {
      mapper.beginTurn("s1");
      final beforeTool = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "Before"},
        }),
      );
      mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-order",
          "kind": "read",
          "status": "completed",
        }),
      );
      final afterTool = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "After"},
        }),
      );

      final beforeId = shared.Message.fromJson(
        beforeTool.whereType<BridgeSseMessageUpdated>().single.info,
      ).id;
      final afterId = shared.Message.fromJson(
        afterTool.whereType<BridgeSseMessageUpdated>().single.info,
      ).id;
      expect(afterId, isNot(beforeId));
      expect(
        afterTool.whereType<BridgeSseMessagePartDelta>().single.delta,
        "After",
      );
    });

    test("tool_call maps to an assistant message with a tool part", () {
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-1",
          "title": "Read file",
          "kind": "read",
          "status": "pending",
        }),
      );
      final updated = events.whereType<BridgeSseMessageUpdated>().single;
      expect(shared.Message.fromJson(updated.info), isA<shared.MessageAssistant>());
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.type, PluginMessagePartType.tool);
      expect(part.tool, "read");
      expect(part.state?.status, PluginToolStatus.pending);
    });

    test("tool_call falls through an empty kind to title and never throws", () {
      // Same fail-soft name resolution as tool_call_update: an empty-string
      // `kind` must fall through to `title`, and a non-string `kind` must not
      // throw during live mapping.
      final emptyKind = mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-empty",
          "kind": "",
          "title": "Search files",
          "status": "pending",
        }),
      );
      expect(
        emptyKind.whereType<BridgeSseMessagePartUpdated>().single.part.tool,
        "Search files",
      );

      final nonStringKind = mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-bad",
          "kind": 123,
          // A non-string title must not throw either — it renders as null.
          "title": {"unexpected": "object"},
          "status": "pending",
        }),
      );
      final badPart = nonStringKind.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(badPart.tool, "tool");
      expect(badPart.state?.title, isNull);
    });

    test("tool_call reads output from the standard ACP content wrapper", () {
      // A spec-compliant ACP agent reports tool output as
      // content: [{type:content, content:{type:text, text:...}}] rather than
      // Cursor's rawOutput. The nested wrapper must be unwrapped, else the tool
      // card renders blank.
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-wrap",
          "kind": "read",
          "status": "completed",
          "content": [
            {
              "type": "content",
              "content": {"type": "text", "text": "wrapped output"},
            },
          ],
        }),
      );
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.state?.output, "wrapped output");
    });

    test("a partial tool_call_update preserves the tool's prior name/title/output", () {
      // Seed the tool card.
      mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-1",
          "kind": "execute",
          "title": "Run tests",
          "status": "pending",
          "rawOutput": {"stdout": "starting"},
        }),
      );

      // A status-only update (the common shape) must NOT reset the name/title
      // to defaults or drop the earlier output.
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-1",
          "status": "completed",
        }),
      );
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.tool, "execute", reason: "name preserved across a partial update");
      expect(part.state?.title, "Run tests", reason: "title preserved");
      expect(part.state?.status, PluginToolStatus.completed, reason: "status advanced");
      expect(part.state?.output, "starting", reason: "prior output preserved when the update omits it");
    });

    test("a title-only tool_call_update keeps the canonical tool id", () {
      mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-2",
          "kind": "edit",
          "title": "Edit main.dart",
          "status": "pending",
        }),
      );
      // An update with a new title but no kind must not overwrite the canonical
      // "edit" identifier with the title text.
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-2",
          "title": "Edit main.dart (revised)",
          "status": "in_progress",
        }),
      );
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.tool, "edit", reason: "no kind → canonical id preserved");
      expect(part.state?.title, "Edit main.dart (revised)");
    });

    test("a first-seen tool_call_update synthesizes the message envelope", () {
      // No prior tool_call (reordered on reconnect/resume/replay, or after the
      // completed entry was pruned): the update must still carry an envelope so
      // the client can render the part instead of dropping an orphan.
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-orphan",
          "kind": "read",
          "status": "in_progress",
        }),
      );
      expect(events.whereType<BridgeSseMessageUpdated>(), hasLength(1));
      expect(events.whereType<BridgeSseMessagePartUpdated>(), hasLength(1));
    });

    test("a completed tool retains its state for a late in-turn update; beginTurn clears it", () {
      mapper.beginTurn("s1");
      mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-3",
          "kind": "read",
          "status": "pending",
        }),
      );
      mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-3",
          "status": "completed",
          "rawOutput": {"stdout": "done"},
        }),
      );
      // A late, reordered output-only update must merge onto the retained
      // terminal state, not blank the finished card.
      final late = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-3",
          "rawOutput": {"stdout": "final"},
        }),
      );
      expect(late.whereType<BridgeSseMessageUpdated>(), isEmpty, reason: "retained → not first-seen");
      final latePart = late.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(latePart.state?.status, PluginToolStatus.completed, reason: "terminal status preserved");
      expect(latePart.tool, "read");
      expect(latePart.state?.output, "final");

      // The next turn clears the prior turn's tools to keep the cache bounded.
      mapper.beginTurn("s1");
      final afterTurn = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-3",
          "status": "in_progress",
        }),
      );
      expect(afterTurn.whereType<BridgeSseMessageUpdated>(), hasLength(1), reason: "cleared on beginTurn → first-seen");
    });

    test("forgetSession drops live tool state for the session", () {
      mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-4",
          "kind": "read",
          "status": "pending",
        }),
      );
      mapper.forgetSession("s1");
      final after = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-4",
          "status": "in_progress",
        }),
      );
      expect(after.whereType<BridgeSseMessageUpdated>(), hasLength(1), reason: "state cleared → first-seen");
    });

    test("forgetSession is exact — a session id that is a colon-prefix of another is unaffected", () {
      AcpNotificationRecord updFor(String sid, Map<String, dynamic> body) => mapAcpNotificationForTest(
        AcpNotification(
          method: "session/update",
          params: {"sessionId": sid, "update": body},
        ),
      );

      // "s1" and "s1:2" collide under a naive "s1:" composite-key prefix match.
      mapper.map(updFor("s1", {"sessionUpdate": "tool_call", "toolCallId": "a", "kind": "read", "status": "pending"}));
      mapper.map(
        updFor("s1:2", {"sessionUpdate": "tool_call", "toolCallId": "b", "kind": "read", "status": "pending"}),
      );

      mapper.forgetSession("s1");

      // "s1:2"'s tool must survive → a follow-up update for it is NOT first-seen.
      final ev = mapper.map(
        updFor("s1:2", {"sessionUpdate": "tool_call_update", "toolCallId": "b", "status": "in_progress"}),
      );
      expect(
        ev.whereType<BridgeSseMessageUpdated>(),
        isEmpty,
        reason: "forgetSession('s1') must not wipe 's1:2' — exact per-session removal",
      );
    });

    test("tool_call_update on an edit emits a session diff", () {
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-2",
          "kind": "edit",
          "status": "completed",
        }),
      );
      expect(events.whereType<BridgeSseSessionDiff>(), hasLength(1));
    });

    test("an initial file-mutating tool_call emits a session diff", () {
      // An agent may report the whole mutation as one complete tool_call with
      // no follow-up update — the diff signal must fire on the initial
      // notification too.
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-init-edit",
          "kind": "edit",
          "status": "completed",
        }),
      );
      expect(events.whereType<BridgeSseSessionDiff>(), hasLength(1));

      final nonMutating = mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-init-read",
          "kind": "read",
          "status": "completed",
        }),
      );
      expect(nonMutating.whereType<BridgeSseSessionDiff>(), isEmpty);
    });

    test("a mutating tool emits its diff when a later status-only update completes it", () {
      final initial = mapper.map(
        update({
          "sessionUpdate": "tool_call",
          "toolCallId": "tc-progress-edit",
          "kind": "edit",
          "status": "in_progress",
        }),
      );
      expect(initial.whereType<BridgeSseSessionDiff>(), isEmpty);

      final completed = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-progress-edit",
          "status": "completed",
        }),
      );
      expect(completed.whereType<BridgeSseSessionDiff>(), hasLength(1));

      final late = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-progress-edit",
          "rawOutput": {"stdout": "done"},
        }),
      );
      expect(late.whereType<BridgeSseSessionDiff>(), isEmpty);
    });

    test("a diff content entry marks the tool call as a file mutation", () {
      // Spec-compliant agents can report an edit purely through the standard
      // tool content shape (type: "diff") with no mutating kind.
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-diff",
          "status": "completed",
          "content": [
            {"type": "diff", "path": "/repo/a.dart", "oldText": "a", "newText": "b"},
          ],
        }),
      );
      expect(events.whereType<BridgeSseSessionDiff>(), hasLength(1));
    });

    test("diff content emits a session diff when status is omitted", () {
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-statusless-diff",
          "content": [
            {"type": "diff", "path": "/repo/a.dart", "oldText": "a", "newText": "b"},
          ],
        }),
      );

      expect(events.whereType<BridgeSseSessionDiff>(), hasLength(1));
    });

    test("chunks group by ACP messageId when present", () {
      mapper.beginTurn("s1");
      final first = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "messageId": "m1",
          "content": {"type": "text", "text": "one"},
        }),
      );
      final firstEnvelope = first.whereType<BridgeSseMessageUpdated>().single;
      final firstId = shared.Message.fromJson(firstEnvelope.info).id;

      // Same id, same role → same message, delta only.
      final more = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "messageId": "m1",
          "content": {"type": "text", "text": " more"},
        }),
      );
      expect(more.whereType<BridgeSseMessageUpdated>(), isEmpty);

      // A change in messageId starts a NEW message even within one turn and
      // one role — the spec's message-boundary signal.
      final second = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "messageId": "m2",
          "content": {"type": "text", "text": "two"},
        }),
      );
      final secondEnvelope = second.whereType<BridgeSseMessageUpdated>().single;
      final secondId = shared.Message.fromJson(secondEnvelope.info).id;
      expect(secondId, isNot(firstId));

      // A later chunk for the FIRST message merges back into it (no envelope,
      // delta targets the first message id).
      final late = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "messageId": "m1",
          "content": {"type": "text", "text": " tail"},
        }),
      );
      expect(late.whereType<BridgeSseMessageUpdated>(), isEmpty);
      expect(late.whereType<BridgeSseMessagePartDelta>().single.messageID, firstId);
    });

    test("plan maps to a todo update, commands mark their project sessions stale", () {
      expect(
        mapper.map(update({"sessionUpdate": "plan", "entries": const <Object?>[]})).single,
        isA<BridgeSseTodoUpdated>(),
      );
      mapper.setSessionProject("s1", "/repo/other");
      expect(
        mapper.map(update({"sessionUpdate": "available_commands_update"})).single,
        isA<BridgeSseSessionsUpdated>()
            .having((event) => event.sessionID, "sessionID", "s1")
            .having((event) => event.projectID, "projectID", "/repo/other"),
      );
    });

    test("tool_call_update surfaces rawOutput stdout/stderr as the part output", () {
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-3",
          "kind": "execute",
          "title": "ls",
          "status": "completed",
          "rawOutput": {"exitCode": 0, "stdout": "a.dart\nb.dart\n", "stderr": ""},
        }),
      );
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.state?.status, PluginToolStatus.completed);
      expect(part.state?.output, "a.dart\nb.dart");
      expect(part.state?.error, isNull);
    });

    test("read-style tool surfaces rawOutput.content", () {
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-read",
          "kind": "read",
          "title": "Read notes.txt",
          "status": "completed",
          "rawOutput": {"content": "hello from cursor e2e\n"},
        }),
      );
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.state?.output, "hello from cursor e2e");
    });

    test("failed tool_call_update mirrors output into error", () {
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-4",
          "kind": "execute",
          "status": "failed",
          "rawOutput": {"exitCode": 1, "stdout": "", "stderr": "boom"},
        }),
      );
      final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(part.state?.status, PluginToolStatus.error);
      expect(part.state?.output, "boom");
      expect(part.state?.error, "boom");
    });

    test("oversized tool output is truncated", () {
      final big = "x" * (maxToolOutputLength + 50);
      final events = mapper.map(
        update({
          "sessionUpdate": "tool_call_update",
          "toolCallId": "tc-5",
          "kind": "execute",
          "status": "completed",
          "rawOutput": {"stdout": big, "stderr": ""},
        }),
      );
      final output = events.whereType<BridgeSseMessagePartUpdated>().single.part.state?.output;
      expect(output, hasLength(maxToolOutputLength + 1)); // 500 chars + ellipsis
      expect(output, endsWith("…"));
    });

    test("session_info_update surfaces the title as a session update", () {
      final events = mapper.map(
        update({
          "sessionUpdate": "session_info_update",
          "title": "Fix the parser",
        }),
      );
      final updated = events.whereType<BridgeSseSessionUpdated>().single;
      expect(updated.titleChanged, isTrue);
      final session = shared.Session.fromJson(updated.info);
      expect(session.id, "s1");
      expect(session.pluginId, "cursor");
      expect(session.title, "Fix the parser");
      // No per-session project recorded -> falls back to the launch cwd.
      expect(session.projectID, "/repo");
      expect(session.directory, "/repo");
    });

    test("session_info_update files the title under the session's own project", () {
      // A session opened outside the launch cwd: its title update must carry
      // that project's id, or the mobile session list (which drops updates whose
      // projectID != the active project) ignores it.
      mapper.setSessionProject("s1", "/repo/opened-elsewhere");
      final events = mapper.map(
        update({
          "sessionUpdate": "session_info_update",
          "title": "Title in opened project",
        }),
      );
      final session = shared.Session.fromJson(events.whereType<BridgeSseSessionUpdated>().single.info);
      expect(session.projectID, "/repo/opened-elsewhere");
      expect(session.directory, "/repo/opened-elsewhere");
    });

    test("clearing a session's project reverts to the launch cwd", () {
      mapper.setSessionProject("s1", "/repo/opened-elsewhere");
      mapper.setSessionProject("s1", null);
      final events = mapper.map(
        update({
          "sessionUpdate": "session_info_update",
          "title": "Back to default",
        }),
      );
      final session = shared.Session.fromJson(events.whereType<BridgeSseSessionUpdated>().single.info);
      expect(session.projectID, "/repo");
    });

    test("session_info_update with an explicit null title forwards a clear", () {
      // ACP v1: title is nullable, null clears it. Dropping the update would
      // leave the phone showing the stale title until a refresh.
      final events = mapper.map(
        update({
          "sessionUpdate": "session_info_update",
          "title": null,
        }),
      );
      final session = shared.Session.fromJson(events.whereType<BridgeSseSessionUpdated>().single.info);
      expect(session.title, isNull);
    });

    test("timestamp-only session_info_update preserves the cached title and emits a session update", () {
      mapper.setSessionSnapshot(
        sessionId: "s1",
        title: "Existing title",
        createdMs: 1000,
        updatedMs: 2000,
      );
      final events = mapper.map(
        update({
          "sessionUpdate": "session_info_update",
          "updatedAt": DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true).toIso8601String(),
        }),
      );
      final updated = events.whereType<BridgeSseSessionUpdated>().single;
      expect(updated.titleChanged, isFalse);
      final session = shared.Session.fromJson(updated.info);
      expect(session.title, "Existing title");
      expect(session.time?.updated, 3000);
    });

    test("session_info_update without a title or timestamp emits nothing", () {
      final events = mapper.map(
        update({
          "sessionUpdate": "session_info_update",
          "_meta": {"tags": <String>[]},
        }),
      );
      expect(events, isEmpty);
    });

    test("session_info_update carries the snapshot time instead of nulling it", () {
      // The mobile list REPLACES the whole session on session.updated, so a
      // null time would drop the row's sort position to epoch 0 whenever no
      // stored bridge row exists to enrich from.
      mapper.setSessionSnapshot(
        sessionId: "s1",
        title: "Old title",
        createdMs: 1000,
        updatedMs: 2000,
      );
      final events = mapper.map(
        update({
          "sessionUpdate": "session_info_update",
          "title": "New title",
        }),
      );
      final session = shared.Session.fromJson(events.whereType<BridgeSseSessionUpdated>().single.info);
      expect(session.title, "New title");
      expect(session.time?.created, 1000);
      expect(session.time?.updated, 2000);
    });

    test("session_info_update honours the notification's own updatedAt", () {
      mapper.setSessionSnapshot(
        sessionId: "s1",
        title: null,
        createdMs: 1000,
        updatedMs: 2000,
      );
      final at = DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true);
      final events = mapper.map(
        update({
          "sessionUpdate": "session_info_update",
          "title": "Fresh",
          "updatedAt": at.toIso8601String(),
        }),
      );
      final session = shared.Session.fromJson(events.whereType<BridgeSseSessionUpdated>().single.info);
      expect(session.time?.updated, 5000);
      expect(session.time?.created, 1000, reason: "creation time is kept, not dragged forward");
    });

    test("snapshot keeps the earliest created and the latest updated", () {
      mapper.setSessionSnapshot(sessionId: "s1", title: null, createdMs: 3000, updatedMs: 3000);
      // An enumeration may report a stale last-activity time. It must not
      // drag either timestamp backwards.
      mapper.setSessionSnapshot(sessionId: "s1", title: null, createdMs: 1000, updatedMs: 4000);
      mapper.setSessionSnapshot(sessionId: "s1", title: null, createdMs: 5000, updatedMs: 3500);
      final events = mapper.map(
        update({
          "sessionUpdate": "session_info_update",
          "title": "T",
        }),
      );
      final session = shared.Session.fromJson(events.whereType<BridgeSseSessionUpdated>().single.info);
      expect(session.time?.created, 1000);
      expect(session.time?.updated, 4000);
    });

    test("with no snapshot at all the emitted time stays null", () {
      final events = mapper.map(
        update({
          "sessionUpdate": "session_info_update",
          "title": "Unknown session",
        }),
      );
      final session = shared.Session.fromJson(events.whereType<BridgeSseSessionUpdated>().single.info);
      expect(session.time, isNull);
    });

    test("a per-session model overrides the global stamp", () {
      mapper
        ..currentModelId = "composer-2.5"
        ..setSessionModel("s1", "claude-opus-4-8", providerId: "cursor");
      mapper.beginTurn("s1");
      final events = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "hi"},
        }),
      );
      final message =
          shared.Message.fromJson(events.whereType<BridgeSseMessageUpdated>().single.info) as shared.MessageAssistant;
      expect(message.modelID, "claude-opus-4-8");
      expect(message.providerID, "cursor");
    });

    test("unknown variants are dropped", () {
      expect(mapper.map(update({"sessionUpdate": "current_mode_update"})), isEmpty);
    });

    test("base mapper never classifies a chunk as a halt notice", () {
      expect(mapper.classifyHaltNotice(text: "Check your settings to continue"), isNull);
    });
  });

  group("AcpEventMapper halt notices", () {
    late _HaltMapper mapper;

    setUp(() {
      mapper = _HaltMapper()
        ..currentModelId = "claude-fable-5"
        ..currentProviderId = "cursor";
    });

    AcpNotificationRecord update(Map<String, dynamic> body) => mapAcpNotificationForTest(
      AcpNotification(
        method: "session/update",
        params: {"sessionId": "s1", "update": body},
      ),
    );

    test("a classified halt notice becomes a lone error message, not assistant text", () {
      mapper.beginTurn("s1");
      final events = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "\n\nHALT: fix it"},
        }),
      );

      final message = shared.Message.fromJson(
        events.whereType<BridgeSseMessageUpdated>().single.info,
      );
      expect(message, isA<shared.MessageError>());
      expect((message as shared.MessageError).errorMessage, "HALT: fix it");
      // No assistant text part or delta — the notice rides in the error message.
      expect(events.whereType<BridgeSseMessagePartUpdated>(), isEmpty);
      expect(events.whereType<BridgeSseMessagePartDelta>(), isEmpty);
    });

    test("a repeated identical halt chunk does not stack duplicate error cards", () {
      mapper.beginTurn("s1");
      mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "HALT: fix it"},
        }),
      );
      final again = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "HALT: fix it"},
        }),
      );
      expect(again, isEmpty);
    });

    test("id-less assistant text after a halt opens a fresh envelope", () {
      mapper.beginTurn("s1");
      final before = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "Before"},
        }),
      );
      mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "HALT: fix it"},
        }),
      );
      final after = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "After"},
        }),
      );

      final beforeId = shared.Message.fromJson(
        before.whereType<BridgeSseMessageUpdated>().single.info,
      ).id;
      // The halt abandons the pre-halt envelope, so the post-halt chunk must
      // open a new one (its own envelope + a different message id), not append a
      // delta to the abandoned envelope.
      final afterId = shared.Message.fromJson(
        after.whereType<BridgeSseMessageUpdated>().single.info,
      ).id;
      expect(afterId, isNot(beforeId));
      expect(after.whereType<BridgeSseMessagePartDelta>().single.delta, "After");
    });

    test("a reasoning chunk is never classified as a halt notice", () {
      mapper.beginTurn("s1");
      final events = mapper.map(
        update({
          "sessionUpdate": "agent_thought_chunk",
          "content": {"type": "text", "text": "HALT: fix it"},
        }),
      );
      expect(
        events.whereType<BridgeSseMessagePartUpdated>().single.part.type,
        PluginMessagePartType.reasoning,
      );
    });

    test("ordinary assistant text still streams as an assistant message", () {
      mapper.beginTurn("s1");
      final events = mapper.map(
        update({
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "real answer"},
        }),
      );
      final message = shared.Message.fromJson(
        events.whereType<BridgeSseMessageUpdated>().single.info,
      );
      expect(message, isA<shared.MessageAssistant>());
      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "real answer");
    });
  });
}

/// Test double: classifies any message whose trimmed text starts with "HALT:"
/// as a halt notice, using the trimmed text as the shown message.
class _HaltMapper extends AcpEventMapper {
  _HaltMapper() : super(launchDirectory: "/repo", agentId: "cursor", pluginId: "cursor");

  @override
  AcpHaltNotice? classifyHaltNotice({required String text}) {
    final trimmed = text.trim();
    if (trimmed.startsWith("HALT:")) {
      return AcpHaltNotice(errorName: "test_halt", message: trimmed);
    }
    return null;
  }
}
