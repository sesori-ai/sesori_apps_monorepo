import 'impl/isolate/isolate.dart';

final isolatesPool = MultiTaskIsolate(
  minPoolSize: 4,
  maxPoolSize: 8,
  debugName: "isolatesPool",
);
