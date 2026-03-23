import "dart:collection";
import "dart:math";

import "package:sesori_shared/sesori_shared.dart" show IterableExtensions;

import "../isolate.dart";
import "multi_task_isolate.dart";
import "multi_task_transient_isolate.dart";

class MultiTaskIsolatePoolImpl implements MultiTaskIsolate {
  final UnmodifiableListView<MultiTaskIsolate> _isolates;
  bool _disposed = false;

  /// The minimum number of tasks that an active isolate must have before
  /// a transient isolate is spun up. This is used to avoid spinning up
  /// transient isolates when there are few tasks to run.
  final int minTasksPerActiveIsolateToSpinTransientIsolate;

  @override
  bool get disposed => _disposed;

  MultiTaskIsolatePoolImpl({
    required int minPoolSize,
    required int maxPoolSize,
    required Duration timeout,
    required String debugName,
    required this.minTasksPerActiveIsolateToSpinTransientIsolate,
  }) : assert(maxPoolSize > 0),
       assert(minTasksPerActiveIsolateToSpinTransientIsolate > 0),
       assert(minPoolSize <= maxPoolSize),
       _isolates = UnmodifiableListView(
         List.generate(
           max(maxPoolSize, 1),
           (index) => index < minPoolSize
               ? MultiTaskIsolateImpl(
                   // Persistent isolates (always present)
                   debugName: "$debugName - #$index",
                   onActiveTaskCountChanged: null,
                 )
               : MultiTaskTransientIsolate(
                   // Transient isolates (optional, created on demand)
                   debugName: "$debugName - #$index",
                   timeout: timeout,
                   eagerStart: false,
                 ),
         ),
       );

  @override
  Future<OUT> run<IN, OUT>(IsolateTask<IN, OUT> task, IN arg) async {
    if (_disposed) {
      throw Exception("IsolatePool has been disposed");
    }

    // Partition the isolates into active and inactive
    // - Active isolates are transient isolates that are currently running tasks and persistent isolates
    // - Inactive isolates are transient isolates that are not currently started
    final (activeIsolates, inactiveIsolates) = _isolates.partition(
      (e) => e is MultiTaskTransientIsolate ? e.isActive : true,
    );

    final topActiveIsolate = _getIsolateWithMinActiveTasks(activeIsolates);
    final firstInactiveIsolate = inactiveIsolates.firstOrNull;

    final MultiTaskIsolate selectedIsolate;

    if (topActiveIsolate == null || firstInactiveIsolate == null) {
      final topIsolate = topActiveIsolate ?? firstInactiveIsolate;
      if (topIsolate == null) {
        // This should never happen
        throw Exception("Internal error: No isolates available");
      }

      selectedIsolate = topIsolate;
    } else if (topActiveIsolate.activeTaskCount < minTasksPerActiveIsolateToSpinTransientIsolate) {
      // If we reached here, we have both active and inactive isolates
      //
      // The active isolates have less than the minimum load threshold, so we
      // send the task to the least loaded active isolate
      selectedIsolate = topActiveIsolate;
    } else {
      // print("Spinning up new isolate");
      // If we reached here, we have both active and inactive isolates
      //
      // The active isolates already have enough tasks, so we need
      // to pick an inactive isolate, spinning it up
      selectedIsolate = firstInactiveIsolate;
    }

    if (IsolateConfigs.debugLogsEnabled) {
      // ignore: avoid_print
      print(
        "Isolate pool debug: running task on isolate [${_isolates.indexOf(selectedIsolate)}] "
        "with [${selectedIsolate.activeTaskCount}] active tasks",
      );
    }
    return selectedIsolate.run(task, arg);
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    for (final value in _isolates) {
      value.dispose();
    }
  }

  @override
  int get activeTaskCount => _isolates.isEmpty
      ? 0
      : _isolates
            .map((e) => e.activeTaskCount) //
            .reduce((previousValue, element) => previousValue + element);
}

MultiTaskIsolate? _getIsolateWithMinActiveTasks(
  List<MultiTaskIsolate> isolates,
) {
  final firstIsolate = isolates.firstOrNull;
  return firstIsolate == null
      ? null
      : isolates.reduceSafe<MultiTaskIsolate>(
          combine: (previous, current) => previous.activeTaskCount < current.activeTaskCount ? previous : current,
          initialValue: firstIsolate,
        );
}
