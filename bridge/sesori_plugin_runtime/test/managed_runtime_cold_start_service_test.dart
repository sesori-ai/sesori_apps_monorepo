import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  late PluginStatusController status;
  late ManagedRuntimeStatusReporter reporter;

  setUp(() {
    status = PluginStatusController(initial: const PluginStarting());
    reporter = ManagedRuntimeStatusReporter(
      status: status,
      clock: _FixedClock(),
      degradedDebounce: const Duration(seconds: 5),
    );
  });

  const service = ManagedRuntimeColdStartService(budget: Duration(milliseconds: 50), logTag: "test");

  test("a cold start completing within the budget reports connected", () async {
    await service.run(coldStart: Future<void>.value(), reporter: reporter);

    expect(status.current, isA<PluginReady>());
  });

  test("a cold start failing within the budget reports degraded without throwing", () async {
    await service.run(coldStart: Future<void>.error(StateError("handshake refused")), reporter: reporter);

    expect(status.current, isA<PluginDegraded>());
  });

  test("a cold start exceeding the budget reports degraded and absorbs its late failure", () async {
    final coldStart = Completer<void>();

    await service.run(coldStart: coldStart.future, reporter: reporter);
    expect(status.current, isA<PluginDegraded>());

    // The background cold start failing later must not surface as an
    // unhandled error; the sink logs it instead.
    coldStart.completeError(StateError("late failure"));
    await pumpEventQueue();
    expect(status.current, isA<PluginDegraded>());
  });
}

class _FixedClock() implements ServerClock {
  @override
  DateTime now() => DateTime.utc(2026, 9, 5);

  @override
  Future<void> delay({required Duration duration}) => Completer<void>().future;
}
