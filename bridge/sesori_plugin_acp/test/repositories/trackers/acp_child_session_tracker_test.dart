import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

AcpChildSpawn _spawn({
  required String childId,
  String? description = "Thing",
  String? prompt,
  bool isBackground = false,
}) => AcpChildSpawn(
  childSessionId: childId,
  description: description,
  agent: "general-purpose",
  prompt: prompt,
  isBackground: isBackground,
);

PluginMessagePartSubtask _subtaskPart(BridgeSseEvent event) =>
    (event as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;

PluginSessionStatus _status(BridgeSseEvent event) => (event as BridgeSseSessionStatus).status;

void main() {
  group("AcpChildSessionTracker", () {
    late AcpChildSessionTracker tracker;

    setUp(() => tracker = AcpChildSessionTracker());
    tearDown(() => tracker.dispose());

    test("spawn creates the child under the root and renders the tile once the prompt streams", () {
      final result = tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "child"),
        directory: "/repo",
      )!;
      expect(result.renderSessionId, "root");
      expect(result.messageId, "root-subagent-child");
      expect(result.opensMessage, isFalse, reason: "no prompt yet: session events only");
      expect(result.events, hasLength(2));
      final created = shared.Session.fromJson((result.events[0] as BridgeSseSessionCreated).info);
      expect(created.id, "child");
      expect(created.parentID, "root");
      expect(created.directory, "/repo");
      expect(created.title, "Thing");
      expect(_status(result.events[1]), const PluginSessionStatus.busy());
      expect(tracker.isChild(sessionId: "child"), isTrue);
      expect(tracker.childStatuses, {"child": const PluginSessionStatus.busy()});
      expect(tracker.busyChildIds(sessionId: "root"), {"child"});
      expect(tracker.runningChildren(sessionId: "root").single.isBackground, isFalse);

      final first = tracker.appendPrompt(childSessionId: "child", delta: "do the ");
      expect(first?.opensMessage, isTrue);
      final tile = _subtaskPart(first!.events.single);
      expect(tile.id, "root-subagent-child-subtask");
      expect(tile.messageID, "root-subagent-child");
      expect(tile.sessionID, "root");
      expect(tile.prompt, "do the ");
      expect(tile.childSessionID, "child");
      expect(tile.taskState?.status, PluginToolStatus.running);

      final second = tracker.appendPrompt(childSessionId: "child", delta: "thing");
      expect(second?.opensMessage, isFalse);
      expect(_subtaskPart(second!.events.single).prompt, "do the thing");
      expect(tracker.appendPrompt(childSessionId: "ghost", delta: "x"), isNull);
      expect(tracker.appendPrompt(childSessionId: "child", delta: ""), isNull);
    });

    test("a spawn that already carries a prompt renders the tile immediately", () {
      final result = tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "child", prompt: "p", isBackground: true),
        directory: "/r",
      )!;
      expect(result.opensMessage, isTrue);
      expect(result.events, hasLength(3));
      expect(_subtaskPart(result.events[2]).prompt, "p");
      expect(tracker.appendPrompt(childSessionId: "child", delta: "p"), isNull);
      expect(tracker.runningChildren(sessionId: "root").single.isBackground, isTrue);
    });

    test("finish completes the tile with bounded output and sets the child idle", () {
      tracker
        ..spawn(
          sessionId: "root",
          spawn: _spawn(childId: "child"),
          directory: "/r",
        )
        ..appendPrompt(childSessionId: "child", delta: "p");

      final events = tracker.finish(
        childSessionId: "child",
        status: PluginToolStatus.completed,
        output: "x" * (maxToolOutputLength + 10),
        error: null,
      );
      final part = _subtaskPart(events[0]);
      expect(part.taskState?.status, PluginToolStatus.completed);
      expect(part.taskState?.output, hasLength(maxToolOutputLength));
      expect(part.taskState?.error, isNull);
      expect(_status(events[1]), const PluginSessionStatus.idle());
      expect(tracker.childStatuses, {"child": const PluginSessionStatus.idle()});
      expect(tracker.busyChildIds(sessionId: "root"), isEmpty);

      expect(
        tracker.finish(childSessionId: "child", status: PluginToolStatus.cancelled, output: null, error: null),
        isEmpty,
        reason: "a second terminal report changes nothing",
      );
      expect(
        tracker.finish(childSessionId: "ghost", status: PluginToolStatus.cancelled, output: null, error: null),
        isEmpty,
      );
    });

    test("a child finish can atomically retain and later release root work", () async {
      tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "child"),
        directory: "/r",
      );
      await pumpEventQueue();
      final changedRoots = <String>[];
      final subscription = tracker.changes.listen((change) => changedRoots.add(change.rootSessionId));
      addTearDown(subscription.cancel);

      final events = tracker.finishAndHoldRoot(
        childSessionId: "child",
        holdId: "opaque-hold",
        status: PluginToolStatus.completed,
        output: null,
        error: null,
      );

      expect(events, hasLength(1));
      expect(tracker.busyChildIds(sessionId: "root"), isEmpty);
      expect(tracker.hasRootHold(sessionId: "root"), isTrue);
      expect(tracker.hasActiveWorkForRoot(sessionId: "root"), isTrue);
      expect(tracker.hasActiveWork, isTrue);
      await pumpEventQueue();
      expect(changedRoots, ["root"]);
      expect(tracker.releaseRootHold(rootSessionId: "root", holdId: "wrong"), isFalse);
      expect(tracker.releaseRootHold(rootSessionId: "root", holdId: "opaque-hold"), isTrue);
      expect(tracker.hasActiveWorkForRoot(sessionId: "root"), isFalse);
      await pumpEventQueue();
      expect(changedRoots, ["root", "root"]);
      expect(tracker.releaseRootHold(rootSessionId: "root", holdId: "opaque-hold"), isFalse);
    });

    test("forgetting a child clears its associated opaque root hold", () async {
      tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "child"),
        directory: "/r",
      );
      tracker.finishAndHoldRoot(
        childSessionId: "child",
        holdId: "not-the-child-id",
        status: PluginToolStatus.completed,
        output: null,
        error: null,
      );
      await pumpEventQueue();

      tracker.forgetSession(sessionId: "child");

      expect(tracker.hasRootHold(sessionId: "root"), isFalse);
      expect(tracker.hasActiveWork, isFalse);
    });

    test("cancelAll clears an autonomous root hold even after its child finished", () async {
      tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "child"),
        directory: "/r",
      );
      tracker.finishAndHoldRoot(
        childSessionId: "child",
        holdId: "opaque-hold",
        status: PluginToolStatus.completed,
        output: null,
        error: null,
      );
      await pumpEventQueue();

      expect(tracker.cancelAll(), isEmpty, reason: "the child already has its terminal events");
      expect(tracker.hasActiveWork, isFalse);
    });

    test("disposal releases an autonomous root hold waiter", () async {
      tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "child"),
        directory: "/r",
      );
      tracker.finishAndHoldRoot(
        childSessionId: "child",
        holdId: "opaque-hold",
        status: PluginToolStatus.completed,
        output: null,
        error: null,
      );
      final waiting = tracker.waitForRootHoldChange(sessionId: "root");

      await tracker.dispose();

      await waiting.timeout(const Duration(seconds: 1));
      expect(tracker.hasRootHold(sessionId: "root"), isFalse);
    });

    test("a finish before any prompt still idles the child without a tile", () {
      tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "child"),
        directory: "/r",
      );
      final events = tracker.finish(
        childSessionId: "child",
        status: PluginToolStatus.completed,
        output: "o",
        error: null,
      );
      expect(events, hasLength(1));
      expect(_status(events.single), const PluginSessionStatus.idle());
    });

    test("cancelled and failed finishes keep only the failure text", () {
      tracker
        ..spawn(
          sessionId: "root",
          spawn: _spawn(childId: "k1", prompt: "p"),
          directory: "/r",
        )
        ..spawn(
          sessionId: "root",
          spawn: _spawn(childId: "k2", prompt: "p"),
          directory: "/r",
        );

      final cancelled = _subtaskPart(
        tracker.finish(childSessionId: "k1", status: PluginToolStatus.cancelled, output: null, error: "stopped")[0],
      );
      expect(cancelled.taskState?.status, PluginToolStatus.cancelled);
      expect(cancelled.taskState?.error, isNull);

      final failed = _subtaskPart(
        tracker.finish(childSessionId: "k2", status: PluginToolStatus.error, output: "partial", error: "boom")[0],
      );
      expect(failed.taskState?.status, PluginToolStatus.error);
      expect(failed.taskState?.error, "boom");
      expect(failed.taskState?.output, isNull);
    });

    test("a nested spawn retains its direct parent while activity rolls up to the root", () {
      tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "child"),
        directory: "/r",
      );
      final nested = tracker.spawn(
        sessionId: "child",
        spawn: _spawn(childId: "grandchild", prompt: "nested"),
        directory: "/r",
      )!;
      expect(nested.renderSessionId, "child");
      expect(shared.Session.fromJson((nested.events[0] as BridgeSseSessionCreated).info).parentID, "child");
      final tile = _subtaskPart(nested.events.last);
      expect(tile.id, "child-subagent-grandchild-subtask");
      expect(tile.messageID, "child-subagent-grandchild");
      expect(tile.sessionID, "child");
      expect(tracker.childSessions(sessionId: "root", directory: "/r").map((session) => session.id), ["child"]);
      expect(tracker.childSessions(sessionId: "child", directory: "/r").map((session) => session.id), [
        "grandchild",
      ]);
      expect(tracker.busyChildIds(sessionId: "root"), {"child", "grandchild"});
      expect(tracker.parentOf(sessionId: "grandchild"), "child");
      expect(tracker.rootOf(sessionId: "grandchild"), "root");
      expect(tracker.rootOf(sessionId: "root"), "root");
    });

    test("forgetting a child removes its full descendant subtree", () {
      tracker
        ..spawn(
          sessionId: "root",
          spawn: _spawn(childId: "child"),
          directory: "/r",
        )
        ..spawn(
          sessionId: "child",
          spawn: _spawn(childId: "grandchild"),
          directory: "/r",
        )
        ..spawn(
          sessionId: "grandchild",
          spawn: _spawn(childId: "great-grandchild"),
          directory: "/r",
        )
        ..spawn(
          sessionId: "root",
          spawn: _spawn(childId: "sibling"),
          directory: "/r",
        );

      expect(tracker.childSessionIds(sessionId: "child"), ["grandchild", "great-grandchild"]);
      tracker.forgetSession(sessionId: "child");

      expect(tracker.childStatuses.keys, ["sibling"]);
      expect(tracker.childSessions(sessionId: "root", directory: "/r").map((session) => session.id), ["sibling"]);
      expect(tracker.busyChildIds(sessionId: "root"), {"sibling"});
      expect(tracker.isChild(sessionId: "grandchild"), isFalse);
      expect(tracker.isChild(sessionId: "great-grandchild"), isFalse);
      expect(
        tracker.spawn(
          sessionId: "child",
          spawn: _spawn(childId: "late-grandchild"),
          directory: "/r",
        ),
        isNull,
      );
      expect(
        tracker.spawn(
          sessionId: "root",
          spawn: _spawn(childId: "child"),
          directory: "/r",
        ),
        isNull,
      );

      tracker.clear();
      expect(
        tracker.spawn(
          sessionId: "root",
          spawn: _spawn(childId: "child"),
          directory: "/r",
        ),
        isNotNull,
        reason: "a new process has drained the deleted process's late frames",
      );
    });

    test("a repeated spawn for a known child is a no-op", () {
      tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "child"),
        directory: "/r",
      );
      final again = tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "child"),
        directory: "/r",
      )!;
      expect(again.events, isEmpty);
      expect(again.opensMessage, isFalse);
      expect(tracker.childStatuses.keys, ["child"]);
    });

    test("the change stream emits only when the running set changes", () async {
      var changes = 0;
      String? changedRoot;
      final subscription = tracker.changes.listen((change) {
        changes++;
        changedRoot = change.rootSessionId;
      });
      addTearDown(subscription.cancel);
      tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "k1"),
        directory: "/r",
      );
      await pumpEventQueue();
      expect(changes, 1);
      expect(changedRoot, "root");
      tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "k1"),
        directory: "/r",
      );
      tracker.appendPrompt(childSessionId: "k1", delta: "p");
      await pumpEventQueue();
      expect(changes, 1, reason: "repeated spawn and prompt chunks leave the running set unchanged");
      tracker.finish(childSessionId: "k1", status: PluginToolStatus.completed, output: null, error: null);
      await pumpEventQueue();
      expect(changes, 2);
      tracker.finish(childSessionId: "k1", status: PluginToolStatus.completed, output: null, error: null);
      tracker.forgetSession(sessionId: "ghost");
      tracker.forgetSession(sessionId: "k1");
      await pumpEventQueue();
      expect(changes, 2, reason: "finished and unknown children do not change activity");
      tracker.spawn(
        sessionId: "root",
        spawn: _spawn(childId: "k2"),
        directory: "/r",
      );
      await pumpEventQueue();
      expect(changes, 3);
      tracker.forgetSession(sessionId: "k2");
      await pumpEventQueue();
      expect(changes, 4);
      tracker.clear();
      await pumpEventQueue();
      expect(changes, 4, reason: "empty bookkeeping is cleared without an activity change");
    });

    test("cancelAll ends every running child cancelled and idle, once", () async {
      tracker
        ..spawn(
          sessionId: "root",
          spawn: _spawn(childId: "k1", prompt: "p"),
          directory: "/r",
        )
        ..spawn(
          sessionId: "other",
          spawn: _spawn(childId: "k2"),
          directory: "/r",
        )
        ..finish(childSessionId: "k2", status: PluginToolStatus.completed, output: null, error: null);
      await pumpEventQueue();
      var changes = 0;
      final subscription = tracker.changes.listen((_) => changes++);
      addTearDown(subscription.cancel);

      final events = tracker.cancelAll();
      await pumpEventQueue();
      expect(_subtaskPart(events[0]).taskState?.status, PluginToolStatus.cancelled);
      expect(_status(events[1]), const PluginSessionStatus.idle());
      expect(events, hasLength(2), reason: "the finished sibling is untouched");
      expect(tracker.hasBusyChildren, isFalse);
      expect(changes, 1);
      expect(tracker.cancelAll(), isEmpty);
      await pumpEventQueue();
      expect(changes, 1);
    });

    test("childSessions lists a root's children as sessions under its directory", () {
      tracker
        ..spawn(
          sessionId: "root",
          spawn: _spawn(childId: "k1", description: "One"),
          directory: "/r",
        )
        ..spawn(
          sessionId: "root",
          spawn: _spawn(childId: "k2", description: null),
          directory: "/r",
        );
      final sessions = tracker.childSessions(sessionId: "root", directory: "/r");
      expect(sessions.map((session) => session.id), ["k1", "k2"]);
      expect(sessions.first.parentID, "root");
      expect(sessions.first.directory, "/r");
      expect(sessions.first.title, "One");
      expect(sessions.last.title, isNull);
      expect(tracker.childSessions(sessionId: "k1", directory: "/r"), isEmpty);
      expect(tracker.hasBusyChildren, isTrue);
    });

    test("forgetting a root drops its children; forgetting a child drops only it; clear drops everything", () {
      tracker
        ..spawn(
          sessionId: "root",
          spawn: _spawn(childId: "k1"),
          directory: "/r",
        )
        ..spawn(
          sessionId: "root",
          spawn: _spawn(childId: "k2"),
          directory: "/r",
        )
        ..spawn(
          sessionId: "other",
          spawn: _spawn(childId: "k3"),
          directory: "/r",
        );

      expect(tracker.childSessionIds(sessionId: "root"), ["k1", "k2"]);
      tracker.forgetSession(sessionId: "k2");
      expect(tracker.childStatuses.keys, ["k1", "k3"]);
      expect(tracker.busyChildIds(sessionId: "root"), {"k1"});

      tracker.forgetSession(sessionId: "root");
      expect(tracker.childStatuses.keys, ["k3"]);
      expect(tracker.runningChildren(sessionId: "root"), isEmpty);

      tracker.clear();
      expect(tracker.childStatuses, isEmpty);
      expect(tracker.isChild(sessionId: "k3"), isFalse);
    });
  });
}
