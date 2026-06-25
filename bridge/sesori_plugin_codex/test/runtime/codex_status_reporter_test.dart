import "dart:async";

import "package:codex_plugin/src/runtime/codex_status_reporter.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  late _ManualClock clock;
  late PluginStatusController status;
  late CodexRuntimeStatusReporter reporter;

  setUp(() {
    clock = _ManualClock();
    status = PluginStatusController(initial: const PluginStarting());
    reporter = CodexRuntimeStatusReporter(
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

  test("markDegradedNow degrades without waiting out the debounce", () {
    reporter.markConnected();
    reporter.markDegradedNow();
    expect(status.current, isA<PluginDegraded>());
  });

  test("after dispose, callbacks are inert", () async {
    reporter.markConnected();
    reporter.dispose();
    reporter.markDisconnected();
    clock.fireAll();
    await pumpEventQueue();
    expect(status.current, isA<PluginReady>());
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
