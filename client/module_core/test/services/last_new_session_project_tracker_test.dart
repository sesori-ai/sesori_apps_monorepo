import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  late BehaviorSubject<ConnectionStatus> status;
  late FakeLastNewSessionProjectStore store;
  late LastNewSessionProjectTracker tracker;

  Matcher known(String? projectId) =>
      isA<LastNewSessionProjectKnown>().having((project) => project.projectId, "projectId", projectId);

  ConnectionStatus connected({required String bridgeId}) => ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay", authToken: "t", bridgeId: bridgeId),
    health: testHealthResponse(),
  );

  LastNewSessionProjectTracker createTracker() {
    final connection = MockConnectionService();
    when(() => connection.status).thenAnswer((_) => status.stream);
    when(() => connection.currentStatus).thenAnswer((_) => status.value);
    return LastNewSessionProjectTracker(connectionService: connection, store: store);
  }

  setUp(() {
    status = BehaviorSubject.seeded(connected(bridgeId: "a"));
    store = FakeLastNewSessionProjectStore()..projectIds["a"] = "one";
    tracker = createTracker();
  });
  tearDown(() async {
    await tracker.dispose();
    await status.close();
  });

  test("the computer's stored project is unknown until read", () async {
    await tracker.dispose();
    tracker = createTracker();
    expect(tracker.project.value, isA<LastNewSessionProjectUnknown>());
    await Future<void>.delayed(Duration.zero);
    expect(tracker.project.value, known("one"));
  });

  test("a recorded project is the computer's at once, and is stored for the next run", () async {
    await Future<void>.delayed(Duration.zero);
    tracker.record(projectId: "two");
    expect(tracker.project.value, known("two"));
    await Future<void>.delayed(Duration.zero);
    expect(store.projectIds, {"a": "two"});

    await tracker.dispose();
    tracker = createTracker();
    await Future<void>.delayed(Duration.zero);
    expect(tracker.project.value, known("two"));
  });

  test("another computer reads its own project, and a disconnect keeps the last one", () async {
    await Future<void>.delayed(Duration.zero);
    status.add(const ConnectionStatus.disconnected());
    await Future<void>.delayed(Duration.zero);
    expect(tracker.project.value, known("one"));

    status.add(connected(bridgeId: "b"));
    await Future<void>.delayed(Duration.zero);
    expect(tracker.project.value, known(null));

    tracker.record(projectId: "three");
    await Future<void>.delayed(Duration.zero);
    expect(store.projectIds, {"a": "one", "b": "three"});
  });
}
