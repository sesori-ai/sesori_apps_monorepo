import "../../isolate.dart";

/// This basically runs the tasks on the main thread
/// - Useful for WEB where we don't have access to Isolates
class MultiTaskIsolateImpl implements MultiTaskIsolate {
  final void Function(int)? onActiveTaskCountChanged;
  final String debugName;

  int _activeTaskCount = 0;

  @override
  int get activeTaskCount => _activeTaskCount;

  bool _disposed = false;

  @override
  bool get disposed => _disposed;

  MultiTaskIsolateImpl({
    required this.onActiveTaskCountChanged,
    required this.debugName,
  });

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
      return await task.staticFunction(arg);
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
  }
}
