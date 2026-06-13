import "dart:async";

import "package:opencode_plugin/src/runtime/open_code_bridge_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  late _ManualClock clock;
  late PluginStatusController status;
  late OpenCodeRuntimeStatusReporter reporter;

  setUp(() {
    clock = _ManualClock();
    status = PluginStatusController(initial: const PluginStarting());
    reporter = OpenCodeRuntimeStatusReporter(
      status: status,
      clock: clock,
      degradedDebounce: const Duration(seconds: 5),
    );
  });

  test("markConnected reports Ready immediately", () {
    reporter.markConnected();
    expect(status.current, isA<PluginReady>());
  });

  test("markDisconnected debounces: degraded only after the window elapses", () async {
    reporter.markConnected();
    reporter.markDisconnected();
    // Still Ready until the debounce delay completes.
    expect(status.current, isA<PluginReady>());

    clock.fireAll();
    await pumpEventQueue();

    expect(status.current, isA<PluginDegraded>());
    final degraded = status.current as PluginDegraded;
    expect(degraded.recoverable, isTrue);
    expect(degraded.requiresUserAction, isFalse);
    expect(degraded.since, equals(clock.startTime));
  });

  test("a reconnect during the debounce window cancels the pending degradation", () async {
    reporter.markConnected();
    reporter.markDisconnected();
    reporter.markConnected();

    clock.fireAll();
    await pumpEventQueue();

    expect(status.current, isA<PluginReady>());
  });

  test("since keeps the first observation across repeated disconnects", () async {
    reporter.markConnected();
    reporter.markDisconnected();
    clock.advance(const Duration(seconds: 1));
    reporter.markDisconnected();
    clock.fireAll();
    await pumpEventQueue();

    expect((status.current as PluginDegraded).since, equals(clock.startTime));
  });

  test("markDegradedNow reports degraded without waiting", () {
    reporter.markConnected();
    reporter.markDegradedNow();
    expect(status.current, isA<PluginDegraded>());
  });

  test("dispose suppresses a pending degradation", () async {
    reporter.markConnected();
    reporter.markDisconnected();
    reporter.dispose();

    clock.fireAll();
    await pumpEventQueue();

    expect(status.current, isA<PluginReady>());
  });

  test("degraded writes are dropped once the plugin is stopping", () {
    reporter.markConnected();
    status.set(const PluginStopping());
    reporter.markDegradedNow();
    expect(status.current, isA<PluginStopping>());
  });
}

class _ManualClock implements ServerClock {
  final DateTime startTime = DateTime.utc(2026, 6, 1, 12);
  late DateTime _now = startTime;
  final List<Completer<void>> _pending = <Completer<void>>[];

  void advance(Duration duration) => _now = _now.add(duration);

  void fireAll() {
    final pending = List<Completer<void>>.of(_pending);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  @override
  DateTime now() => _now;

  @override
  Future<void> delay({required Duration duration}) {
    final completer = Completer<void>();
    _pending.add(completer);
    return completer.future;
  }
}
