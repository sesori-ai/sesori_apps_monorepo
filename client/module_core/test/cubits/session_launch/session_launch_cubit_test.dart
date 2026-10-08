import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  late SessionLaunchRepository repository;
  late SessionLaunchCubit cubit;

  setUp(() {
    repository = inMemorySessionLaunchRepository();
    cubit = SessionLaunchCubit(launchService: inMemorySessionLaunchService(launchRepository: repository));
  });

  tearDown(() => cubit.close());

  void start({required String launchId, required String text, required int minute}) => repository.start(
    launchId: launchId,
    projectId: "project-1",
    pluginId: "claude",
    startedAt: DateTime.utc(2026, 10, 7, 12, minute),
    projectName: "Sesori",
    submission: NewSessionSubmissionSnapshot.text(
      draft: ComposerDraft.typed(text: text),
      attachments: const [],
    ),
  );

  test(
    "waiting launches are listed newest first, titled by their first line; created ones name their session",
    () async {
      start(launchId: "launch-1", text: "Fix the bug\nin the parser", minute: 0);
      start(launchId: "launch-2", text: "  ", minute: 1);
      repository.promote(
        launchId: "launch-1",
        session: testSession(id: "session-1"),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.launching.map((launch) => (launch.launchId, launch.title)), [("launch-2", null)]);
      expect(cubit.state.sessionIds, {"launch-1": "session-1"});

      start(launchId: "launch-3", text: "Fix the bug\nin the parser", minute: 2);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.launching.first.title, "Fix the bug");
    },
  );

  test("a launch created after its composer left names its session before it goes", () async {
    final states = <SessionLaunchState>[];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);

    start(launchId: "launch-1", text: "Left", minute: 0);
    repository.releaseHandoff(launchId: "launch-1");
    repository.promote(
      launchId: "launch-1",
      session: testSession(id: "session-1"),
    );
    await Future<void>.delayed(Duration.zero);

    expect(states.map((state) => state.sessionIds), contains(equals({"launch-1": "session-1"})));
    expect(cubit.state.launching, isEmpty);
    expect(cubit.state.sessionIds, isEmpty);
  });

  test("only a failure after the composer left reaches the failure alerts", () async {
    final failures = <SessionLaunchFailedAfterLeaving>[];
    final subscription = cubit.failuresAfterLeaving.listen(failures.add);
    addTearDown(subscription.cancel);

    start(launchId: "launch-1", text: "Composing", minute: 0);
    repository.fail(launchId: "launch-1", reason: RemoteFailureReason.serverRejected);
    start(launchId: "launch-2", text: "Left", minute: 1);
    repository.releaseHandoff(launchId: "launch-2");
    repository.fail(launchId: "launch-2", reason: RemoteFailureReason.serverRejected);
    await Future<void>.delayed(Duration.zero);

    expect(failures.map((failure) => (failure.launchId, failure.projectName)), [("launch-2", "Sesori")]);
    expect(cubit.state.launching, isEmpty);
  });
}
