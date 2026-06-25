import "dart:async";

import "../isolate.dart";
import "../multi_task/multi_task_isolate.dart";
import "../multi_task/multi_task_transient_isolate.dart";

class SingleTaskIsolateImpl<IN, OUT> implements SingleTaskIsolate<IN, OUT> {
  final MultiTaskIsolate _sharedIsolate;
  final IsolateTask<IN, OUT> _task;

  SingleTaskIsolateImpl.transient({
    required IsolateTask<IN, OUT> task,
    required bool eagerStart,
    required String debugName,
    required Duration timeout,
  }) : _task = task,
       _sharedIsolate = MultiTaskTransientIsolate(
         eagerStart: eagerStart,
         timeout: timeout,
         debugName: debugName,
       );

  SingleTaskIsolateImpl.persistent({
    required IsolateTask<IN, OUT> task,
    required String debugName,
  }) : _task = task,
       _sharedIsolate = MultiTaskIsolateImpl(
         onActiveTaskCountChanged: null,
         debugName: debugName,
       );

  @override
  void dispose() => _sharedIsolate.dispose();

  @override
  bool get disposed => _sharedIsolate.disposed;

  @override
  int get activeTaskCount => _sharedIsolate.activeTaskCount;

  @override
  Future<OUT> run(IN arg) => _sharedIsolate.run(_task, arg);
}
