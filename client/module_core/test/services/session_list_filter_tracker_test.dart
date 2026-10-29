import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  const one = ProjectSummary(id: "one", name: "One", path: "/one", time: null);
  const two = ProjectSummary(id: "two", name: "Two", path: "/two", time: null);
  late MockProjectRepository repository;
  late BehaviorSubject<ConnectionStatus> status;
  late ProjectListService projectListService;
  late SessionListFilterTracker tracker;

  ConnectionStatus connected({required String bridgeId}) => ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay", authToken: "t", bridgeId: bridgeId),
    health: testHealthResponse(),
  );

  setUp(() {
    repository = MockProjectRepository();
    final connection = MockConnectionService();
    status = BehaviorSubject.seeded(connected(bridgeId: "a"));
    when(() => connection.status).thenAnswer((_) => status.stream);
    when(() => connection.currentStatus).thenAnswer((_) => status.value);
    projectListService = ProjectListService(
      repository: repository,
    );
    tracker = SessionListFilterTracker(connectionService: connection, projectListService: projectListService);
  });
  tearDown(() async {
    await tracker.dispose();
    await projectListService.dispose();
    await status.close();
  });

  test("the filter holds its project until that project leaves the list", () async {
    expect(tracker.projectId.value, isNull);
    tracker.select(projectId: two.id);
    when(repository.listProjects).thenAnswer((_) async => ApiResponse.success(const Projects(data: [one, two])));
    await projectListService.listProjects();
    expect(tracker.projectId.value, two.id);

    projectListService.removeProjectAndPublish(projects: const [one, two], projectId: one.id);
    expect(tracker.projectId.value, two.id, reason: "another project left");
    projectListService.removeProjectAndPublish(projects: const [two], projectId: two.id);
    expect(tracker.projectId.value, isNull);
  });

  test("another computer clears the filter, and reconnecting to the same one keeps it", () async {
    tracker.select(projectId: one.id);
    status
      ..add(const ConnectionStatus.disconnected())
      ..add(connected(bridgeId: "a"));
    await Future<void>.delayed(Duration.zero);
    expect(tracker.projectId.value, one.id);

    status.add(connected(bridgeId: "b"));
    await Future<void>.delayed(Duration.zero);
    expect(tracker.projectId.value, isNull);
  });
}
