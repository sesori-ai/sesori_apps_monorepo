import "dart:async";

import "package:rxdart/rxdart.dart";

/// A [Stream] that converts a single-subscription Stream into a broadcast Stream that replays
/// the latest value to any new listener while subscribed (if [replayLastValueToNewListeners] is true.
/// Once all subscribers have canceled or the stream completes, the underlying subscription is canceled.
///
/// Adding listeners after the stream has completed/disposed and the [delayBeforeCancel] time has passed
/// will result in a new broadcast stream being created with [_factory] and shared to new listeners.
class RefCountReusableStream<T> extends Stream<T> {
  final bool replayLastValueToNewListeners;
  final Duration delayBeforeCancel;
  final void Function()? onCancel;
  final Stream<T> Function() _factory;
  StreamSubscription<T>? _subscription;
  StreamController<T>? _controller;

  RefCountReusableStream._(
    this._factory, {
    required this.replayLastValueToNewListeners,
    required this.delayBeforeCancel,
    this.onCancel,
  });

  RefCountReusableStream.publish(
    Stream<T> Function() factory, {
    Duration delayBeforeCancel = Duration.zero,
    void Function()? onCancel,
  }) : this._(
         factory,
         replayLastValueToNewListeners: false,
         delayBeforeCancel: delayBeforeCancel,
         onCancel: onCancel,
       );

  RefCountReusableStream.behaviour(
    Stream<T> Function() factory, {
    Duration delayBeforeCancel = Duration.zero,
    void Function()? onCancel,
  }) : this._(
         factory,
         replayLastValueToNewListeners: true,
         delayBeforeCancel: delayBeforeCancel,
         onCancel: onCancel,
       );

  Timer? _disposeTask;

  void _requestDispose() {
    _disposeTask ??= Timer(delayBeforeCancel, () {
      final onCancel = this.onCancel;
      unawaited(_subscription?.cancel());
      if (onCancel != null) onCancel();
      _subscription = null;
      _controller = null;
      _disposeTask = null;
    });
  }

  @override
  StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _disposeTask?.cancel();
    _disposeTask = null;

    final controller = _controller;
    if (controller == null) {
      final newController = replayLastValueToNewListeners
          ? BehaviorSubject<T>(onCancel: _requestDispose, sync: true)
          : PublishSubject<T>(onCancel: _requestDispose, sync: true);
      _controller = newController;
      _subscription = _factory().listen(
        newController.add,
        onError: newController.addError,
        onDone: () {
          _subscription = null;
          _controller = null;
          unawaited(newController.close());
        },
      );
      return newController.stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
    }

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
