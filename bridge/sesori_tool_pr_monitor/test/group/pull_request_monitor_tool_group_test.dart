import "package:clock/clock.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart";
import "package:sesori_tool_pr_monitor/src/group/pull_request_monitor_tool_group.dart";
import "package:sesori_tool_pr_monitor/src/listeners/pull_request_poll_listener.dart";
import "package:sesori_tool_pr_monitor/src/repositories/pull_request_watch_repository.dart";
import "package:sesori_tool_pr_monitor/src/services/pull_request_watch_service.dart";
import "package:test/test.dart";

import "../support/pull_request_builders.dart";
import "../support/watch_fakes.dart";

void main() {
  late FakeHost host;
  late MemoryStore store;
  late FakeActions actions;
  late FakeSnapshots snapshots;
  late PullRequestMonitorToolGroup group;

  setUp(() {
    store = MemoryStore();
    host = FakeHost(records: store)
      ..addSession(sessionId: "root")
      ..addSession(sessionId: "child", rootSessionId: "root");
    snapshots = FakeSnapshots();
    actions = FakeActions();
    final service = PullRequestWatchService(
      snapshots: snapshots,
      actions: actions,
      watches: PullRequestWatchRepository(store: store),
      host: host,
      activity: activity,
      readiness: readiness,
      reports: reports,
      feedback: feedback,
      clock: Clock.fixed(DateTime.utc(2026, 11, 25, 12)),
    );
    group = PullRequestMonitorToolGroup(
      watches: service,
      poller: PullRequestPollListener(service: service, host: host),
    );
  });

  Future<SesoriToolResult> call({
    required String tool,
    required String session,
    String? pr,
    Map<String, Object?> extra = const {},
  }) => group.call(
    tool: tool,
    caller: SesoriToolCaller(sessionId: session),
    arguments: {"pr": ?pr, ...extra},
  );

  test("a sub-agent's watch lands on its root and shows in the root's status", () async {
    snapshots.enqueue(emptySnapshot);
    final started = await call(tool: "watch_pr", session: "child", pr: "https://github.com/sesori/example/pull/42");
    expect(started, isA<SesoriToolSuccess>());
    expect(started.text, startsWith('Started watching sesori/example#42 — "test PR".'));
    expect(started.text, contains("[PR Monitor] [sesori/example#42]"));
    expect(store.sessionRecords["root"]?.keys, ["sesori/example#42"]);

    final status = await call(tool: "pr_watch_status", session: "root");
    expect(
      status.text,
      "sesori/example#42 — watching, quiet, last report 0m ago, ready: no\n"
      "This computer polls 1 watched PR once a minute.",
    );

    expect(
      (await call(tool: "unwatch_pr", session: "root", pr: "sesori/example#42")).text,
      "Stopped watching sesori/example#42.",
    );
    expect(store.sessionRecords["root"], isEmpty);
  });

  test("a missing or malformed PR, an unknown caller and an unwatched report fail with the reason", () async {
    await expectLater(call(tool: "watch_pr", session: "root"), throwsA(isA<InvalidToolArguments>()));
    expect((await call(tool: "watch_pr", session: "root", pr: "example#42")).text, startsWith("Invalid PR identifier"));
    expect(
      (await call(tool: "watch_pr", session: "gone", pr: "sesori/example#42")).text,
      "This session is no longer known to Sesori.",
    );
    expect(
      (await call(tool: "get_pr_report", session: "root", pr: "sesori/example#42")).text,
      "This session is not watching sesori/example#42; call watch_pr first.",
    );
  });

  test("reply_on_pr posts in a thread or on the PR, and get_pr_feedback reads the PR", () async {
    expect(
      (await call(
        tool: "reply_on_pr",
        session: "root",
        pr: "sesori/example#42",
        extra: {"body": "Fixed.", "thread_id": "PRRT_1"},
      )).text,
      "Replied on thread PRRT_1: https://github.com/sesori/example/pull/42#reply",
    );
    expect(
      (await call(
        tool: "reply_on_pr",
        session: "root",
        pr: "sesori/example#42",
        extra: {"body": "Done.", "thread_id": ""},
      )).text,
      "Posted a PR comment on sesori/example#42: https://github.com/sesori/example/pull/42#reply",
    );
    expect(actions.calls, ["reply PRRT_1: Fixed.", "reply comment: Done."]);
    await expectLater(
      call(tool: "reply_on_pr", session: "root", pr: "sesori/example#42"),
      throwsA(isA<InvalidToolArguments>()),
    );

    snapshots.enqueue(emptySnapshot);
    expect(
      (await call(tool: "get_pr_feedback", session: "root", pr: "sesori/example#42")).text,
      "No feedback on sesori/example#42 is awaiting a reply.",
    );
  });
}
