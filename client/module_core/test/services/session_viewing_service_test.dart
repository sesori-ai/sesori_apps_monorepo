import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/session_view_repository.dart";
import "package:test/test.dart";

class MockSessionViewRepository extends Mock implements SessionViewRepository {}

class FakeLifecycleSource implements LifecycleSource {
  final BehaviorSubject<LifecycleState> _subject = BehaviorSubject.seeded(LifecycleState.resumed);
  @override
  ValueStream<LifecycleState> get lifecycleStateStream => _subject.stream;
  void emit(LifecycleState state) => _subject.add(state);
  void close() => _subject.close();
}

void main() {
  group("SessionViewingService", () {
    late MockSessionViewRepository viewRepository;
    late FakeLifecycleSource lifecycle;

    setUp(() {
      viewRepository = MockSessionViewRepository();
      lifecycle = FakeLifecycleSource();
      when(() => viewRepository.sendSessionView(sessionId: any(named: "sessionId"))).thenAnswer((_) async {});
    });

    tearDown(() => lifecycle.close());

    SessionViewingService build() => SessionViewingService(
      viewRepository: viewRepository,
      lifecycleSource: lifecycle,
    );

    test("setViewingSession sends the session id", () async {
      final service = build()..setViewingSession("s1");
      await service.sendTail;
      verify(() => viewRepository.sendSessionView(sessionId: "s1")).called(1);
    });

    test("clearViewingSession sends null only when the id matches the current view", () async {
      final service = build()..setViewingSession("s1");
      await service.sendTail;
      clearInteractions(viewRepository);

      service.clearViewingSession("other");
      verifyNever(() => viewRepository.sendSessionView(sessionId: any(named: "sessionId")));

      service.clearViewingSession("s1");
      await service.sendTail;
      verify(() => viewRepository.sendSessionView(sessionId: null)).called(1);
    });

    test("background sends null and keeps the session; resume alone does NOT re-assert", () async {
      final service = build()..setViewingSession("s1");
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      clearInteractions(viewRepository);

      lifecycle.emit(LifecycleState.paused);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      verify(() => viewRepository.sendSessionView(sessionId: null)).called(1);

      // Resume must NOT auto-re-assert: the bridge would mark the session seen
      // before the detail screen shows the refreshed transcript. The cubit
      // re-calls setViewingSession after its post-resume refresh instead.
      lifecycle.emit(LifecycleState.resumed);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => viewRepository.sendSessionView(sessionId: any(named: "sessionId")));

      // The cubit's explicit post-refresh re-assert is what re-declares it.
      service.setViewingSession("s1");
      await service.sendTail;
      verify(() => viewRepository.sendSessionView(sessionId: "s1")).called(1);
      service.clearViewingSession("s1");
      await service.sendTail;
    });

    test("setViewingSession while backgrounded does not send; only an explicit re-call after resume sends", () async {
      final service = build();
      lifecycle.emit(LifecycleState.paused);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      clearInteractions(viewRepository);

      // A deferred load finishing while backgrounded must not declare viewing.
      service.setViewingSession("s1");
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => viewRepository.sendSessionView(sessionId: any(named: "sessionId")));

      // Resume flips the paused flag but does not itself send.
      lifecycle.emit(LifecycleState.resumed);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => viewRepository.sendSessionView(sessionId: any(named: "sessionId")));

      // The cubit re-asserts after its refresh renders.
      service.setViewingSession("s1");
      await service.sendTail;
      verify(() => viewRepository.sendSessionView(sessionId: "s1")).called(1);
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

      verify(() => viewRepository.sendSessionView(sessionId: null)).called(1);
      service.clearViewingSession("s1");
      await service.sendTail;
    });
  });
}
