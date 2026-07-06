import "dart:async";

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

    test("setViewingSession while backgrounded declares nothing until re-asserted after resume", () async {
      final service = build();
      lifecycle.emit(LifecycleState.paused);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      clearInteractions(viewRepository);

      // A deferred load finishing while backgrounded must not declare viewing:
      // the send executes while paused, so it transmits null.
      service.setViewingSession("s1");
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => viewRepository.sendSessionView(sessionId: "s1"));

      // Resume flips the paused flag but does not itself send.
      lifecycle.emit(LifecycleState.resumed);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => viewRepository.sendSessionView(sessionId: "s1"));

      // The cubit re-asserts after its refresh renders.
      service.setViewingSession("s1");
      await service.sendTail;
      verify(() => viewRepository.sendSessionView(sessionId: "s1")).called(1);
      service.clearViewingSession("s1");
      await service.sendTail;
    });

    test("a send queued behind a slow send transmits the state current at execution (background)", () async {
      // Gate the first send so a second declaration queues behind it and
      // executes only after the app has backgrounded.
      final gate = Completer<void>();
      var firstCall = true;
      when(() => viewRepository.sendSessionView(sessionId: any(named: "sessionId"))).thenAnswer((_) async {
        if (firstCall) {
          firstCall = false;
          await gate.future;
        }
      });

      final service = build()..setViewingSession("s1");
      // Let the first s1 send start and park on the gate (in-flight, pre-pause).
      await Future<void>.delayed(Duration.zero);
      // A second declaration for the still-current session queues behind it.
      service.setViewingSession("s1");
      // Background before the queued send executes.
      lifecycle.emit(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await service.sendTail;

      final sent = verify(() => viewRepository.sendSessionView(sessionId: captureAny(named: "sessionId"))).captured;
      // The in-flight send went out as s1; every send executed after the pause
      // transmitted the paused state (null) — never a viewer while hidden.
      expect(sent.first, equals("s1"));
      expect(sent.sublist(1).whereType<String>(), isEmpty);
      expect(sent, contains(null));
    });

    test("a send superseded by navigation never declares the stale session", () async {
      // Gate the first send so the s1 navigation lands before it executes.
      final gate = Completer<void>();
      var firstCall = true;
      when(() => viewRepository.sendSessionView(sessionId: any(named: "sessionId"))).thenAnswer((_) async {
        if (firstCall) {
          firstCall = false;
          await gate.future;
        }
      });

      final service = build()..setViewingSession("s0");
      // Navigate to s1 before s0's queued send executes: s0 is no longer
      // current when any send runs, so it is never declared.
      service.setViewingSession("s1");
      gate.complete();
      await service.sendTail;

      final sent = verify(() => viewRepository.sendSessionView(sessionId: captureAny(named: "sessionId"))).captured;
      expect(sent.contains("s0"), isFalse);
      expect(sent.last, equals("s1"));
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
