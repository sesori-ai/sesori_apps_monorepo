// ignore_for_file: no_slop_linter/prefer_required_named_parameters, no_slop_linter/prefer_exhaustive_switch
import "dart:async";

import "multi_task/multi_task_isolate.dart";
import "multi_task/multi_task_isolate_pool.dart";
import "multi_task/multi_task_transient_isolate.dart";
import "single_task/single_task_isolate.dart";
import "single_task/single_task_isolate_pool.dart";

final class IsolateConfigs {
  const IsolateConfigs._();

  static const int minTasksPerActiveIsolateToSpinTransientIsolate = 10;
  static const Duration transientDefaultTimeout = Duration(seconds: 10);
  static bool debugLogsEnabled = false;
}

class IsolateTask<IN, OUT> {
  final FutureOr<OUT> Function(IN arg) staticFunction;

  const IsolateTask(this.staticFunction);
}

abstract interface class MultiTaskIsolate {
  int get activeTaskCount;
  bool get disposed;
  void dispose();
  Future<OUT> run<IN, OUT>(IsolateTask<IN, OUT> task, IN arg);

  /// Creates a flexible multi task isolate (pool)
  factory MultiTaskIsolate({
    int minPoolSize = 1, // default to single isolate
    int maxPoolSize = 1, // default to single isolate
    Duration timeout = IsolateConfigs.transientDefaultTimeout,
    int minTasksPerActiveIsolateToSpinTransientIsolate = IsolateConfigs.minTasksPerActiveIsolateToSpinTransientIsolate,
    String? debugName,
  }) => switch ((minPoolSize, maxPoolSize)) {
    (1, 1) => MultiTaskIsolateImpl(
      onActiveTaskCountChanged: null,
      debugName: debugName ?? "MultiTaskIsolate(Persistent)",
    ),
    (0, 1) => MultiTaskTransientIsolate(
      timeout: timeout,
      eagerStart: false,
      debugIndex: 0,
      debugName: debugName ?? "MultiTaskIsolate(Transient)",
    ),
    _ => MultiTaskIsolatePoolImpl(
      minPoolSize: minPoolSize,
      maxPoolSize: maxPoolSize,
      timeout: timeout,
      minTasksPerActiveIsolateToSpinTransientIsolate: minTasksPerActiveIsolateToSpinTransientIsolate,
      debugName: debugName ?? "MultiTaskIsolatePool($minPoolSize-$maxPoolSize)",
    ),
  };
}

abstract interface class SingleTaskIsolate<IN, OUT> {
  int get activeTaskCount;
  bool get disposed;
  Future<OUT> run(IN arg);
  void dispose();

  /// Creates a flexible single task isolate (pool)
  factory SingleTaskIsolate({
    required IsolateTask<IN, OUT> task,
    int minPoolSize = 1, // default to single isolate
    int maxPoolSize = 1, // default to single isolate
    Duration timeout = IsolateConfigs.transientDefaultTimeout,
    int minTasksPerActiveIsolateToSpinTransientIsolate = IsolateConfigs.minTasksPerActiveIsolateToSpinTransientIsolate,
    String? debugName,
  }) => switch ((minPoolSize, maxPoolSize)) {
    (1, 1) => SingleTaskIsolateImpl.persistent(
      task: task,
      debugName: debugName ?? "SingleTaskIsolate(Persistent)",
    ),
    (0, 1) => SingleTaskIsolateImpl.transient(
      task: task,
      eagerStart: false,
      debugName: debugName ?? "SingleTaskIsolate(Transient)",
      timeout: timeout,
    ),
    _ => SingleTaskIsolatePoolImpl(
      task: task,
      minPoolSize: minPoolSize,
      maxPoolSize: maxPoolSize,
      timeout: timeout,
      minTasksPerActiveIsolateToSpinTransientIsolate: minTasksPerActiveIsolateToSpinTransientIsolate,
      debugName: debugName ?? "SingleTaskIsolatePool($minPoolSize-$maxPoolSize)",
    ),
  };
}
