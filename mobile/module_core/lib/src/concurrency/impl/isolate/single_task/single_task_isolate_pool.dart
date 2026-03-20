// ignore_for_file: no_slop_linter/prefer_required_named_parameters
import "../isolate.dart";
import "../multi_task/mulit_task_isolate_pool.dart";

class SingleTaskIsolatePoolImpl<IN, OUT> implements SingleTaskIsolate<IN, OUT> {
  final MultiTaskIsolatePoolImpl _pool;
  final IsolateTask<IN, OUT> _task;

  @override
  bool get disposed => _pool.disposed;

  @override
  int get activeTaskCount => _pool.activeTaskCount;

  @override
  void dispose() => _pool.dispose();

  @override
  Future<OUT> run(IN arg) => _pool.run(_task, arg);

  SingleTaskIsolatePoolImpl({
    required IsolateTask<IN, OUT> task,
    required int minPoolSize,
    required int maxPoolSize,
    required Duration timeout,
    required int minTasksPerActiveIsolateToSpinTransientIsolate,
    String? debugName,
  }) : _task = task,
       _pool = MultiTaskIsolatePoolImpl(
         minPoolSize: minPoolSize,
         maxPoolSize: maxPoolSize,
         timeout: timeout,
         minTasksPerActiveIsolateToSpinTransientIsolate: minTasksPerActiveIsolateToSpinTransientIsolate,
         debugName: debugName ?? "SingleTaskIsolatePool($minPoolSize-$maxPoolSize)",
       );
}
