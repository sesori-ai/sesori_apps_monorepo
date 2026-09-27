import "dart:async";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  late SessionLaunchStorage storage;
  late SessionLaunchRepository repository;
  late List<SessionLaunchOutcome> outcomes;
  late StreamSubscription<SessionLaunchOutcome> subscription;
  final submission = NewSessionSubmissionSnapshot.text(
    draft: ComposerDraft.typed(text: "Hello"),
    attachments: const [],
  );
  final startedAt = DateTime.utc(2026, 9, 27, 12);

  setUp(() {
    storage = SessionLaunchStorage();
    repository = SessionLaunchRepository(storage: storage);
    outcomes = [];
    subscription = repository.outcomes.listen(outcomes.add);
  });

  tearDown(() => subscription.cancel());

  void start({String launchId = "launch-1"}) => repository.start(
    launchId: launchId,
    projectId: "project-1",
    pluginId: "claude",
    startedAt: startedAt,
    submission: submission,
  );

  test("hands the first message over once, and only for its own created session", () async {
    start();
    expect(repository.takeHandoff(sessionId: "session-1"), isNull, reason: "a pending launch has no session yet");

    repository.promote(
      launchId: "launch-1",
      session: testSession(id: "session-1"),
    );
    expect(repository.takeHandoff(sessionId: "session-2"), isNull);

    final handoff = repository.takeHandoff(sessionId: "session-1");
    expect(
      handoff,
      SessionLaunchHandoff(submission: submission, pluginId: "claude", startedAt: startedAt, followUpIds: const {}),
    );
    expect(repository.takeHandoff(sessionId: "session-1"), isNull);
    expect(storage.readAll(), isEmpty, reason: "nothing is owed once the handoff is taken");
    await Future<void>.delayed(Duration.zero);
    expect(outcomes, [
      SessionLaunchOutcome.succeeded(
        launchId: "launch-1",
        session: testSession(id: "session-1"),
      ),
    ]);
  });

  test("a launch released while pending promotes to nothing left to hand over", () async {
    start();
    repository.releaseHandoff(launchId: "launch-1");
    expect(
      storage.read(launchId: "launch-1"),
      isA<PendingSessionLaunch>().having((l) => l.submission, "submission", isNull),
    );

    repository.promote(
      launchId: "launch-1",
      session: testSession(id: "session-1"),
    );

    expect(storage.readAll(), isEmpty);
    expect(repository.takeHandoff(sessionId: "session-1"), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(outcomes.single, isA<SessionLaunchSucceeded>());
  });

  test("releasing a created launch discards its handoff", () {
    start();
    repository.promote(
      launchId: "launch-1",
      session: testSession(id: "session-1"),
    );
    repository.releaseHandoff(launchId: "launch-1");

    expect(storage.readAll(), isEmpty);
    expect(repository.takeHandoff(sessionId: "session-1"), isNull);
  });

  test("a failure goes to the composer while it holds the payload, and nowhere else", () async {
    start();
    repository.fail(launchId: "launch-1", reason: RemoteFailureReason.networkDown);

    expect(storage.readAll(), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(outcomes, [
      const SessionLaunchOutcome.failedWhileComposing(launchId: "launch-1", reason: RemoteFailureReason.networkDown),
    ]);
  });

  test("a failure after the composer left is reported with its project, and only that way", () async {
    start();
    repository.releaseHandoff(launchId: "launch-1");
    repository.fail(launchId: "launch-1", reason: RemoteFailureReason.serverRejected);

    expect(storage.readAll(), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(outcomes, [
      const SessionLaunchOutcome.failedAfterLeaving(
        launchId: "launch-1",
        projectId: "project-1",
        reason: RemoteFailureReason.serverRejected,
      ),
    ]);
  });

  test("concurrent launches are kept apart", () {
    start(launchId: "launch-1");
    start(launchId: "launch-2");
    repository.promote(
      launchId: "launch-2",
      session: testSession(id: "session-2"),
    );

    expect(repository.takeHandoff(sessionId: "session-2"), isNotNull);
    expect(storage.readAll().single, isA<PendingSessionLaunch>().having((l) => l.launchId, "launchId", "launch-1"));
  });
}
