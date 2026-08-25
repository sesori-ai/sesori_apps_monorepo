import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  late _ManualClock clock;
  late PluginStatusController status;
  late ManagedRuntimeStatusReporter reporter;

  setUp(() {
    clock = _ManualClock();
    status = PluginStatusController(initial: const PluginStarting());
    reporter = ManagedRuntimeStatusReporter(
      status: status,
      clock: clock,
      degradedDebounce: const Duration(seconds: 5),
    );
  });

  test("markConnected reports ready immediately", () {
    reporter.markConnected();

    expect(status.current, isA<PluginReady>());
  });

  test("repeated disconnects schedule one degraded transition", () async {
    reporter.markConnected();
    reporter.markDisconnected();
    reporter.markDisconnected();

    expect(status.current, isA<PluginReady>());
    expect(clock.pendingCount, 1);

    clock.fireAll();
    await pumpEventQueue();

    final degraded = status.current as PluginDegraded;
    expect(degraded.since, clock.startTime);
    expect(degraded.recoverable, isTrue);
    expect(degraded.requiresUserAction, isFalse);
  });

  test("reconnect cancels pending degradation by generation", () async {
    reporter.markConnected();
    reporter.markDisconnected();
    reporter.markConnected();

    clock.fireAll();
    await pumpEventQueue();

    expect(status.current, isA<PluginReady>());
  });

  test("markDegradedNow degrades immediately", () {
    reporter.markConnected();
    reporter.markDegradedNow();

    expect(status.current, isA<PluginDegraded>());
    expect(clock.pendingCount, 0);
  });

  test("dispose cancels pending work and makes callbacks inert", () async {
    reporter.markConnected();
    reporter.markDisconnected();
    reporter.dispose();
    reporter.markDegradedNow();
    reporter.markDisconnected();
    reporter.markConnected();

    clock.fireAll();
    await pumpEventQueue();

    expect(status.current, isA<PluginReady>());
  });
}

class _ManualClock() implements ServerClock {
  final DateTime startTime = DateTime.utc(2026, 8, 24, 12);
  final List<Completer<void>> _pending = <Completer<void>>[];

  int get pendingCount => _pending.length;

  void fireAll() {
    final pending = List<Completer<void>>.of(_pending);
    _pending.clear();
    for (final completer in pending) {
      completer.complete();
    }
  }

  @override
  DateTime now() => startTime;

  @override
  Future<void> delay({required Duration duration}) {
    final completer = Completer<void>();
    _pending.add(completer);
    return completer.future;
  }
}
