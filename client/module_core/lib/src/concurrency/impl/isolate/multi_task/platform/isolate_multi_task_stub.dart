// ignore_for_file: avoid_unused_constructor_parameters

import "../../isolate.dart";

class MultiTaskIsolateImpl implements MultiTaskIsolate {
  MultiTaskIsolateImpl({
    required void Function(int)? onActiveTaskCountChanged,
    required String debugName,
  });

  @override
  int get activeTaskCount => throw UnimplementedError("stub: activeTaskCount");

  @override
  void dispose() {
    throw UnimplementedError("stub: dispose");
  }

  @override
  bool get disposed => throw UnimplementedError("stub: disposed");

  @override
  Future<OUT> run<IN, OUT>(IsolateTask<IN, OUT> task, IN arg) {
    throw UnimplementedError("stub: run");
  }
}
