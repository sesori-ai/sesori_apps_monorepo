import "dart:async";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RefCountReusableStream.publish", () {
    test("multiple subscribers share same source stream", () async {
      final source = _SourceHarness<int>();
      final stream = RefCountReusableStream<int>.publish(source.createStream);
      final firstValues = <int>[];
      final secondValues = <int>[];

      final firstSubscription = stream.listen(firstValues.add);
      final secondSubscription = stream.listen(secondValues.add);

      expect(source.factoryCallCount, equals(1));

      source.emit(value: 1);
      await pumpEventQueue();

      expect(firstValues, equals([1]));
      expect(secondValues, equals([1]));

      await firstSubscription.cancel();
      await secondSubscription.cancel();
      await _pumpZeroDelay();
    });

    test("all subscribers cancel cancels source stream", () async {
      final source = _SourceHarness<int>();
      final stream = RefCountReusableStream<int>.publish(source.createStream);

      final firstSubscription = stream.listen((_) {});
      final secondSubscription = stream.listen((_) {});

      await firstSubscription.cancel();
      expect(source.cancelCount, equals(0));

      await secondSubscription.cancel();
      await _pumpZeroDelay();

      expect(source.cancelCount, equals(1));
    });

    test("re-subscribing after cancel creates a new source", () async {
      final source = _SourceHarness<int>();
      final stream = RefCountReusableStream<int>.publish(source.createStream);

      final firstSubscription = stream.listen((_) {});
      await firstSubscription.cancel();
      await _pumpZeroDelay();

      final secondSubscription = stream.listen((_) {});

      expect(source.factoryCallCount, equals(2));

      await secondSubscription.cancel();
      await _pumpZeroDelay();
    });

    test("forwards source errors to subscribers", () async {
      final source = _SourceHarness<int>();
      final stream = RefCountReusableStream<int>.publish(source.createStream);
      final firstErrors = <Object>[];
      final secondErrors = <Object>[];

      final firstSubscription = stream.listen(
        (_) {},
        onError: firstErrors.add,
      );
      final secondSubscription = stream.listen(
        (_) {},
        onError: secondErrors.add,
      );
      final error = StateError("boom");

      source.emitError(error: error);
      await pumpEventQueue();

      expect(firstErrors, equals([error]));
      expect(secondErrors, equals([error]));

      await firstSubscription.cancel();
      await secondSubscription.cancel();
      await _pumpZeroDelay();
    });

    test("propagates source completion to subscribers", () async {
      final source = _SourceHarness<int>();
      final stream = RefCountReusableStream<int>.publish(source.createStream);
      final firstDone = Completer<void>();
      final secondDone = Completer<void>();

      stream.listen(
        (_) {},
        onDone: firstDone.complete,
      );
      stream.listen(
        (_) {},
        onDone: secondDone.complete,
      );

      await source.close();
      await Future.wait([firstDone.future, secondDone.future]);
      await _pumpZeroDelay();

      expect(source.factoryCallCount, equals(1));
    });
  });

  group("RefCountReusableStream.behaviour", () {
    test("new subscriber receives last emitted value", () async {
      final source = _SourceHarness<int>();
      final stream = RefCountReusableStream<int>.behaviour(source.createStream);
      final firstValues = <int>[];
      final secondValues = <int>[];

      final firstSubscription = stream.listen(firstValues.add);
      source.emit(value: 1);
      await pumpEventQueue();

      final secondSubscription = stream.listen(secondValues.add);
      await pumpEventQueue();

      expect(firstValues, equals([1]));
      expect(secondValues, equals([1]));

      await firstSubscription.cancel();
      await secondSubscription.cancel();
      await _pumpZeroDelay();
    });
  });

  group("RefCountReusableStream lifecycle", () {
    test("delayBeforeCancel keeps source alive until delay expires", () async {
      final source = _SourceHarness<int>();
      final stream = RefCountReusableStream<int>.publish(
        source.createStream,
        delayBeforeCancel: const Duration(milliseconds: 40),
      );

      final firstSubscription = stream.listen((_) {});
      await firstSubscription.cancel();

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(source.cancelCount, equals(0));

      final secondSubscription = stream.listen((_) {});
      expect(source.factoryCallCount, equals(1));

      await secondSubscription.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(source.cancelCount, equals(1));
    });

    test("calls onCancel when source is cancelled", () async {
      final source = _SourceHarness<int>();
      var onCancelCount = 0;
      final stream = RefCountReusableStream<int>.publish(
        source.createStream,
        onCancel: () => onCancelCount++,
      );

      final subscription = stream.listen((_) {});

      await subscription.cancel();
      await _pumpZeroDelay();

      expect(source.cancelCount, equals(1));
      expect(onCancelCount, equals(1));
    });

    test("handles concurrent subscribe and unsubscribe churn", () async {
      final source = _SourceHarness<int>();
      final stream = RefCountReusableStream<int>.publish(source.createStream);
      final receivedValues = <int>[];
      final anchorSubscription = stream.listen(receivedValues.add);
      final subscriptions = <StreamSubscription<int>>[];

      for (var index = 0; index < 25; index++) {
        subscriptions.add(stream.listen(receivedValues.add));

        if (index.isEven) {
          await subscriptions.removeAt(0).cancel();
        }

        source.emit(value: index);
        await pumpEventQueue();
      }

      await Future.wait(subscriptions.map((subscription) => subscription.cancel()));
      await anchorSubscription.cancel();
      await _pumpZeroDelay();

      expect(source.factoryCallCount, equals(1));
      expect(source.cancelCount, equals(1));
      expect(receivedValues, isNotEmpty);
    });
  });
}

Future<void> _pumpZeroDelay() => Future<void>.delayed(Duration.zero);

class _SourceHarness<T> {
  final List<StreamController<T>> _controllers = <StreamController<T>>[];
  int factoryCallCount = 0;
  int cancelCount = 0;

  Stream<T> createStream() {
    factoryCallCount += 1;
    final controller = StreamController<T>(
      sync: true,
      onCancel: () {
        cancelCount += 1;
      },
    );
    _controllers.add(controller);
    return controller.stream;
  }

  void emit({required T value}) {
    _controllers.last.add(value);
  }

  void emitError({required Object error}) {
    _controllers.last.addError(error);
  }

  Future<void> close() {
    return _controllers.last.close();
  }
}
