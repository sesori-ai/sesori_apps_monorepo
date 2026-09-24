import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/listeners/session_continuation_timer_listener.dart";
import "package:sesori_bridge/src/services/session_continuation_service.dart";
import "package:test/test.dart";

void main() {
  test("a failed immediate tick rearms the regular interval", () {
    fakeAsync((time) {
      final service = _Service()..failNext = true;
      final listener = SessionContinuationTimerListener(
        service: service,
        timerFactory: ({required delay, required callback}) => Timer(delay, callback),
      );
      listener.start();
      time.flushMicrotasks();
      expect(service.calls, 1);
      time.elapse(const Duration(seconds: 29));
      expect(service.calls, 1);
      time.elapse(const Duration(seconds: 1));
      expect(service.calls, 2);
      unawaited(listener.dispose());
      time.flushMicrotasks();
      time.elapse(const Duration(minutes: 1));
      expect(service.calls, 2);
    });
  });

  test("ticks cannot overlap and disposing an in-flight tick prevents rearming", () {
    fakeAsync((time) {
      final pending = Completer<void>();
      final service = _Service()..pending = pending.future;
      final listener = SessionContinuationTimerListener(
        service: service,
        timerFactory: ({required delay, required callback}) => Timer(delay, callback),
      );
      listener.start();
      time.flushMicrotasks();
      time.elapse(const Duration(minutes: 3));
      expect(service.calls, 1);
      var disposed = false;
      unawaited(
        listener.dispose().then((_) {
          disposed = true;
        }),
      );
      time.flushMicrotasks();
      expect(disposed, isFalse);
      pending.complete();
      time.flushMicrotasks();
      expect(disposed, isTrue);
      time.elapse(const Duration(minutes: 3));
      expect(service.calls, 1);
      expect(time.pendingTimers, isEmpty);
    });
  });
}

class _Service() implements SessionContinuationService {
  int calls = 0;
  bool failNext = false;
  Future<void>? pending;
  @override
  Future<void> runDue() async {
    calls++;
    if (failNext) {
      failNext = false;
      throw StateError("fixture tick failed");
    }
    await pending;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
