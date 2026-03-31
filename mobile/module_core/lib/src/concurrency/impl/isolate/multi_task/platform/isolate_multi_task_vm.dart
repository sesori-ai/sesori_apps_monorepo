import "dart:async";
import "dart:isolate";

import "../../isolate.dart";

/// This is the VM implementation of the reusable isolate
class MultiTaskIsolateImpl implements MultiTaskIsolate {
  final _receivePort = ReceivePort();
  late final Future<SendPort> _sendPort;
  late final Future<Isolate> _isolate;

  final void Function(int)? onActiveTaskCountChanged;

  int _activeTaskCount = 0;

  @override
  int get activeTaskCount => _activeTaskCount;

  bool _disposed = false;

  @override
  bool get disposed => _disposed;

  MultiTaskIsolateImpl({
    required this.onActiveTaskCountChanged,
    required String debugName,
  }) {
    _isolate = Isolate.spawn(
      // ignore: inference_failure_on_function_invocation, Isolate.spawn generic inference is intentional here
      _isolateEntry,
      _receivePort.sendPort,
      debugName: debugName,
    );
    // ignore: no_slop_linter/avoid_as_cast, Cannot avoid force-cast when dealing with Isolate
    _sendPort = _receivePort.first.then((e) => e as SendPort);
  }

  @override
  Future<OUT> run<IN, OUT>(IsolateTask<IN, OUT> task, IN arg) async {
    if (_disposed) {
      throw Exception("Isolate has been disposed");
    }

    final onActiveTaskCountChanged = this.onActiveTaskCountChanged;

    _activeTaskCount++;

    if (onActiveTaskCountChanged != null) {
      onActiveTaskCountChanged(_activeTaskCount);
    }

    try {
      final taskReceivePort = ReceivePort();
      final taskWithArgAndSendPort = _IsolateTaskWithArgAndSendPort(
        task: task,
        arg: arg,
        sendPort: taskReceivePort.sendPort,
      );
      (await _sendPort).send(taskWithArgAndSendPort);

      // Listen for the result and print it when it arrives
      final result = await taskReceivePort.first;
      if (result is _IsolateErrorWrapper) {
        throw result.error;
      } else {
        // ignore: no_slop_linter/avoid_as_cast, Cannot avoid force-cast when dealing with Isolate
        return result as OUT;
      }
    } finally {
      _activeTaskCount--;

      if (onActiveTaskCountChanged != null) {
        onActiveTaskCountChanged(_activeTaskCount);
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    unawaited(
      _isolate.then(
        (value) {
          value.kill(priority: Isolate.immediate);
          _receivePort.close();
        },
      ),
    );
  }
}

@pragma("vm:prefer-inline")
void _isolateEntry<IN, OUT>(SendPort sendPort) {
  final receivePort = ReceivePort();

  sendPort.send(receivePort.sendPort);

  receivePort.listen((wrapper) async {
    // ignore: no_slop_linter/avoid_as_cast, Cannot avoid force-cast when dealing with Isolate
    wrapper as _IsolateTaskWithArgAndSendPort<IN, OUT>;
    final sendPort = wrapper.sendPort;
    try {
      // print("${Isolate.current.debugName}: Running ${wrapper.task.runtimeType}");
      final result = await wrapper.run();
      // print("${Isolate.current.debugName}: Running ${taskArg.runtimeType}");
      sendPort.send(result);
    } catch (err) {
      sendPort.send(_IsolateErrorWrapper(err));
    }
  });
}

final class _IsolateErrorWrapper {
  final Object error;

  _IsolateErrorWrapper(this.error);
}

final class _IsolateTaskWithArgAndSendPort<IN, OUT> {
  final IsolateTask<IN, OUT> task;
  final IN arg;
  final SendPort sendPort;

  const _IsolateTaskWithArgAndSendPort({
    required this.task,
    required this.arg,
    required this.sendPort,
  });

  @pragma("vm:prefer-inline")
  FutureOr<OUT> run() => task.staticFunction(arg);
}
