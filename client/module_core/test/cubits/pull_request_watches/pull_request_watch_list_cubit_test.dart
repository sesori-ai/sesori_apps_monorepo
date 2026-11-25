import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

ConnectionStatus _connected({String bridgeId = "bridge"}) => ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: bridgeId),
  health: const HealthResponse(healthy: true, version: "1.16.0", filesystemAccessDegraded: false),
);

PullRequestWatchListItem _item({
  required int number,
  String sessionId = "session-1",
  bool autoMerge = false,
  PullRequestWatchStatus status = const PullRequestWatchStatus.waiting(),
}) => PullRequestWatchListItem(
  sessionId: sessionId,
  sessionTitle: "Fixture session",
  projectId: "project-1",
  watch: SessionPullRequestWatch(
    repository: "acme/widgets",
    number: number,
    title: "Fixture change $number",
    url: "https://github.com/acme/widgets/pull/$number",
    autoMerge: autoMerge,
    status: status,
  ),
);

void main() {
  late MockPullRequestWatchRepository repository;
  late MockSessionRepository sessions;
  late MockConnectionService connection;
  late StreamController<SseEvent> events;
  late BehaviorSubject<ConnectionStatus> statuses;

  setUp(() {
    repository = MockPullRequestWatchRepository();
    sessions = MockSessionRepository();
    connection = MockConnectionService();
    events = StreamController<SseEvent>.broadcast();
    statuses = BehaviorSubject<ConnectionStatus>.seeded(_connected());
    when(() => connection.events).thenAnswer((_) => events.stream);
    when(() => connection.status).thenAnswer((_) => statuses);
    when(() => connection.currentStatus).thenAnswer((_) => statuses.value);
    addTearDown(events.close);
    addTearDown(statuses.close);
  });

  void answerList(List<PullRequestWatchListItem> watches) =>
      when(() => repository.listWatches()).thenAnswer((_) async => PullRequestWatchListSuccess(watches: watches));

  PullRequestWatchListCubit create() {
    final cubit = PullRequestWatchListCubit(
      repository: repository,
      sessionRepository: sessions,
      connectionService: connection,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  List<PullRequestWatchListItem> watchesOf(PullRequestWatchListCubit cubit) =>
      (cubit.state as PullRequestWatchListLoaded).watches;

  test("loads the watches and counts the ones that need the user", () async {
    answerList([
      _item(number: 1),
      _item(number: 2, status: const PullRequestWatchStatus.needsYou(reasons: [PullRequestWatchNeed.ciFailing])),
    ]);
    final cubit = create();
    expect(cubit.state, isA<PullRequestWatchListLoading>());

    await pumpEventQueue();

    expect((cubit.state as PullRequestWatchListLoaded).needsYouCount, 1);
  });

  test("reloads when the bridge says the watches changed", () async {
    answerList([_item(number: 1)]);
    final cubit = create();
    await pumpEventQueue();

    answerList([_item(number: 1), _item(number: 2)]);
    events.add(SseEvent(data: const SesoriSseEvent.pullRequestWatchesChanged()));
    await pumpEventQueue();

    expect(watchesOf(cubit).map((item) => item.watch.number), [1, 2]);
  });

  test("an older bridge without the list is unsupported", () async {
    when(() => repository.listWatches()).thenAnswer((_) async => const PullRequestWatchListBridgeOutdated());
    final cubit = create();
    await pumpEventQueue();

    expect(cubit.state, isA<PullRequestWatchListUnsupported>());
  });

  test("switching computers forgets the previous computer's watches", () async {
    answerList([_item(number: 1)]);
    final cubit = create();
    await pumpEventQueue();

    final next = Completer<PullRequestWatchListResult>();
    when(() => repository.listWatches()).thenAnswer((_) => next.future);
    statuses.add(
      const ConnectionStatus.reconnecting(
        config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: "other"),
      ),
    );
    await pumpEventQueue();
    expect(cubit.state, isA<PullRequestWatchListLoading>());

    statuses.add(_connected(bridgeId: "other"));
    await pumpEventQueue();
    next.complete(const PullRequestWatchListSuccess(watches: []));
    await pumpEventQueue();
    expect(watchesOf(cubit), isEmpty);
  });

  group("auto-merge", () {
    test("moves at once and takes the bridge's answer", () async {
      final item = _item(number: 1);
      answerList([item]);
      final cubit = create();
      await pumpEventQueue();
      final answer = Completer<ApiResponse<Session>>();
      when(
        () => sessions.setPullRequestWatchAutoMerge(
          sessionId: "session-1",
          repository: "acme/widgets",
          number: 1,
          enabled: true,
        ),
      ).thenAnswer((_) => answer.future);

      final result = cubit.setAutoMerge(item: item, enabled: true);
      await pumpEventQueue();
      expect(watchesOf(cubit).single.watch.autoMerge, isTrue);

      answer.complete(
        ApiResponse.success(
          testSession(id: "session-1").copyWith(
            pullRequestWatches: [item.watch.copyWith(autoMerge: true, status: const PullRequestWatchStatus.ready())],
          ),
        ),
      );
      expect(await result, isTrue);
      expect(watchesOf(cubit).single.watch.status, isA<PullRequestWatchStatusReady>());
    });

    test("a failure goes back and says so", () async {
      final item = _item(number: 1);
      answerList([item]);
      final cubit = create();
      await pumpEventQueue();
      when(
        () => sessions.setPullRequestWatchAutoMerge(
          sessionId: any(named: "sessionId"),
          repository: any(named: "repository"),
          number: any(named: "number"),
          enabled: any(named: "enabled"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      expect(await cubit.setAutoMerge(item: item, enabled: true), isFalse);
      expect(watchesOf(cubit).single.watch.autoMerge, isFalse);
    });
  });

  group("stop", () {
    test("marks the row stopping, then removes it", () async {
      final item = _item(number: 1);
      answerList([item, _item(number: 2)]);
      final cubit = create();
      await pumpEventQueue();
      final answer = Completer<ApiResponse<Session>>();
      when(
        () => sessions.stopPullRequestWatch(sessionId: "session-1", repository: "acme/widgets", number: 1),
      ).thenAnswer((_) => answer.future);

      final result = cubit.stop(item: item);
      await pumpEventQueue();
      expect((cubit.state as PullRequestWatchListLoaded).stopping, {item.key});

      answer.complete(ApiResponse.success(testSession(id: "session-1")));
      expect(await result, isTrue);
      final state = cubit.state as PullRequestWatchListLoaded;
      expect(state.watches.map((item) => item.watch.number), [2]);
      expect(state.stopping, isEmpty);
    });

    test("a failure keeps the row", () async {
      final item = _item(number: 1);
      answerList([item]);
      final cubit = create();
      await pumpEventQueue();
      when(
        () => sessions.stopPullRequestWatch(
          sessionId: any(named: "sessionId"),
          repository: any(named: "repository"),
          number: any(named: "number"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      expect(await cubit.stop(item: item), isFalse);
      final state = cubit.state as PullRequestWatchListLoaded;
      expect(state.watches, [item]);
      expect(state.stopping, isEmpty);
    });
  });
}
