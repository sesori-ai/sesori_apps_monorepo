import "dart:async";

import "../isolate.dart";
import "multi_task_isolate.dart";
import "platform/isolate_multi_task_stub.dart"
    if (dart.library.io) "platform/isolate_multi_task_vm.dart"
    if (dart.library.js) "platform/isolate_multi_task_web.dart"
    if (dart.library.js_interop) "platform/isolate_multi_task_web.dart"
    if (dart.library.html) "platform/isolate_multi_task_web.dart";

class MultiTaskTransientIsolate implements MultiTaskIsolate {
  Timer? _inactivityTimer;
  final Duration _timeout;

  final String _debugName;
  final int _debugIndex;

  MultiTaskIsolate? _isolate;

  bool _disposed = false;

  /// Whether the isolate is currently active.
  bool get isActive => _isolate != null;

  @override
  bool get disposed => _disposed;

  @override
  int get activeTaskCount => _isolate?.activeTaskCount ?? 0;

  MultiTaskTransientIsolate({
    required Duration timeout,
    required bool eagerStart,
    required String debugName,
    int debugIndex = 0,
  }) : _timeout = timeout,
       _debugName = debugName,
       _debugIndex = debugIndex {
    if (eagerStart) {
      _isolate = _setupNewIsolate(debugName: _debugName, index: debugIndex);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _inactivityTimer?.cancel();
    _isolate?.dispose();
    _isolate = null;
  }

  @override
  Future<OUT> run<IN, OUT>(IsolateTask<IN, OUT> task, IN arg) {
    if (_disposed) {
      throw Exception("Isolate has been disposed");
    }

    final isolate = _isolate ??= _setupNewIsolate(debugName: _debugName, index: _debugIndex);

    return isolate.run(task, arg);
  }

  MultiTaskIsolate _setupNewIsolate({
    required String debugName,
    required int index,
  }) {
    assert(_isolate == null);
    if (IsolateConfigs.debugLogsEnabled) {
      // ignore: avoid_print
      print("Isolate transient debug: creating new isolate");
    }

    void onActiveTaskCountChanged(int activeTasksCount) {
      if (IsolateConfigs.debugLogsEnabled) {
        // ignore: avoid_print
        print("Isolate transient debug: canceling scheduled isolate dispose: $activeTasksCount active tasks");
      }
      _inactivityTimer?.cancel();
      _inactivityTimer = null;

      if (activeTasksCount == 0) {
        if (IsolateConfigs.debugLogsEnabled) {
          // ignore: avoid_print
          print("Isolate transient debug: scheduling isolate dispose");
        }

        _inactivityTimer = Timer(_timeout, () {
          if (IsolateConfigs.debugLogsEnabled) {
            // ignore: avoid_print
            print("Isolate transient debug: disposing isolate");
          }
          _isolate?.dispose();
          _isolate = null;
        });
      }
    }

    final newIsolate = MultiTaskIsolateImpl(
      onActiveTaskCountChanged: onActiveTaskCountChanged,
      debugName: "$debugName - #$index",
    );

    return newIsolate;
  }
}
