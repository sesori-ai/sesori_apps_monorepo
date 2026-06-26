import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/session_view_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockSessionViewRepository extends Mock implements SessionViewRepository {}

class MockConnectionService extends Mock implements ConnectionService {}

class FakeLifecycleSource implements LifecycleSource {
  final BehaviorSubject<LifecycleState> _subject = BehaviorSubject.seeded(LifecycleState.resumed);
  @override
  ValueStream<LifecycleState> get lifecycleStateStream => _subject.stream;
  void emit(LifecycleState state) => _subject.add(state);
  void close() => _subject.close();
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com");
const _connected = ConnectionStatus.connected(
  config: _config,
  health: HealthResponse(healthy: true, version: "1.0.0"),
);
const _reconnecting = ConnectionStatus.reconnecting(config: _config);

void main() {
  group("SessionViewingService", () {
    late MockSessionViewRepository viewRepository;
    late MockConnectionService connectionService;
    late BehaviorSubject<ConnectionStatus> status;
    late FakeLifecycleSource lifecycle;

    setUp(() {
      viewRepository = MockSessionViewRepository();
      connectionService = MockConnectionService();
      status = BehaviorSubject<ConnectionStatus>.seeded(_connected);
      lifecycle = FakeLifecycleSource();
      when(() => connectionService.status).thenAnswer((_) => status.stream);
      when(() => viewRepository.sendSessionView(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await status.close();
      lifecycle.close();
    });

    SessionViewingService build() => SessionViewingService(
      viewRepository: viewRepository,
      connectionService: connectionService,
      lifecycleSource: lifecycle,
    );

    test("setViewingSession sends the session id", () async {
      final service = build()..setViewingSession("s1");
      await service.sendTail;
      verify(() => viewRepository.sendSessionView("s1")).called(1);
    });

    test("clearViewingSession sends null only when the id matches the current view", () async {
      final service = build()..setViewingSession("s1");
      await service.sendTail;
      clearInteractions(viewRepository);

      service.clearViewingSession("other");
      verifyNever(() => viewRepository.sendSessionView(any()));

      service.clearViewingSession("s1");
      await service.sendTail;
      verify(() => viewRepository.sendSessionView(null)).called(1);
    });

    test("re-asserts the current view when the connection returns to connected", () async {
      final service = build()..setViewingSession("s1");
      // Let the seeded status/lifecycle replay settle, then isolate the reconnect.
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      clearInteractions(viewRepository);

      status.add(_reconnecting);
      status.add(_connected);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);

      verify(() => viewRepository.sendSessionView("s1")).called(1);
      service.clearViewingSession("s1");
      await service.sendTail;
    });

    test("background sends null but keeps the session; resume re-asserts", () async {
      final service = build()..setViewingSession("s1");
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      clearInteractions(viewRepository);

      lifecycle.emit(LifecycleState.paused);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      verify(() => viewRepository.sendSessionView(null)).called(1);

      lifecycle.emit(LifecycleState.resumed);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      verify(() => viewRepository.sendSessionView("s1")).called(1);
      service.clearViewingSession("s1");
      await service.sendTail;
    });

    test("hidden + paused fired back-to-back only sends one clear", () async {
      final service = build()..setViewingSession("s1");
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      clearInteractions(viewRepository);

      // Mobile emits `hidden` then `paused` when backgrounding.
      lifecycle.emit(LifecycleState.hidden);
      lifecycle.emit(LifecycleState.paused);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);

      verify(() => viewRepository.sendSessionView(null)).called(1);
      service.clearViewingSession("s1");
      await service.sendTail;
    });
  });
}
