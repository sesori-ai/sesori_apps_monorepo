import 'dart:async';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('SteadyPluginLifecycle', () {
    test('starts as Starting and markReady applies immediately', () {
      final plugin = _SteadyPlugin();

      expect(plugin.currentStatus, const PluginStarting());
      plugin.reportReady();
      expect(plugin.currentStatus, const PluginReady());
    });

    test('status stream replays the latest value', () async {
      final plugin = _SteadyPlugin();
      plugin.reportReady();

      expect(await plugin.status.first, const PluginReady());
    });

    group('degraded debounce', () {
      test('a degradation is not reported before the debounce elapses', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();

        plugin.reportDegraded();

        expect(plugin.currentStatus, const PluginReady());
        expect(plugin.clock.pendingDelayDurations, [plugin.degradedDebounceForTest]);
      });

      test('a persistent degradation is reported with the first observation time', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();
        final observedAt = plugin.clock.now();

        plugin.reportDegraded(requiresUserAction: true, userActionHint: 'log in again');
        plugin.clock.advance(const Duration(seconds: 9));
        await plugin.clock.firePendingDelays();

        final status = plugin.currentStatus;
        expect(status, isA<PluginDegraded>());
        status as PluginDegraded;
        expect(status.since, observedAt);
        expect(status.requiresUserAction, isTrue);
        expect(status.userActionHint, 'log in again');
      });

      test('markReady cancels a pending degradation', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();

        plugin.reportDegraded();
        plugin.reportReady();
        await plugin.clock.firePendingDelays();

        expect(plugin.currentStatus, const PluginReady());
      });

      test('repeated marks while pending coalesce into one report', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();

        plugin.reportDegraded();
        plugin.clock.advance(const Duration(seconds: 1));
        plugin.reportDegraded();

        expect(plugin.clock.pendingDelayDurations, hasLength(1));
      });

      test('an escalation during the pending window wins, keeping the first observation time', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();
        final observedAt = plugin.clock.now();

        plugin.reportDegraded();
        plugin.clock.advance(const Duration(seconds: 1));
        plugin.reportDegraded(requiresUserAction: true, userActionHint: 're-authenticate');
        await plugin.clock.firePendingDelays();

        final status = plugin.currentStatus;
        expect(status, isA<PluginDegraded>());
        status as PluginDegraded;
        expect(status.since, observedAt);
        expect(status.requiresUserAction, isTrue);
        expect(status.userActionHint, 're-authenticate');
      });

      test('while already degraded, details update immediately and since is kept', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();
        final observedAt = plugin.clock.now();
        plugin.reportDegraded();
        await plugin.clock.firePendingDelays();

        plugin.clock.advance(const Duration(minutes: 1));
        plugin.reportDegraded(recoverable: false);

        final status = plugin.currentStatus;
        expect(status, isA<PluginDegraded>());
        status as PluginDegraded;
        expect(status.since, observedAt);
        expect(status.recoverable, isFalse);
      });

      test('markReady restores Ready immediately from Degraded', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();
        plugin.reportDegraded();
        await plugin.clock.firePendingDelays();
        expect(plugin.currentStatus, isA<PluginDegraded>());

        plugin.reportReady();

        expect(plugin.currentStatus, const PluginReady());
      });
    });

    test('markFailed reports a terminal failure', () {
      final plugin = _SteadyPlugin();
      plugin.reportReady();

      plugin.reportFailed('backend gone', cause: 'socket closed');

      expect(plugin.currentStatus, const PluginFailed(reason: 'backend gone', cause: 'socket closed'));
    });

    group('shutdown', () {
      test('emits Stopping then Stopped around onShutdown', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();
        final seen = <PluginStatus>[];
        final subscription = plugin.status.listen(seen.add);

        await plugin.shutdown(budget: const Duration(seconds: 5));
        await pumpEventQueue();

        expect(plugin.onShutdownCalls, 1);
        expect(plugin.lastBudget, const Duration(seconds: 5));
        expect(seen, [const PluginReady(), const PluginStopping(), const PluginStopped()]);
        await subscription.cancel();
      });

      test('is idempotent: repeated calls share one teardown', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();

        await plugin.shutdown();
        await plugin.shutdown();

        expect(plugin.onShutdownCalls, 1);
        expect(plugin.currentStatus, const PluginStopped());
      });

      test('works after a terminal failure', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();
        plugin.reportFailed('backend gone');

        await plugin.shutdown();

        expect(plugin.currentStatus, const PluginStopped());
      });

      test('drops a markFailed arriving during shutdown', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();

        await plugin.shutdown();
        plugin.reportFailed('exit monitor fired late');

        expect(plugin.currentStatus, const PluginStopped());
      });

      test('drops a pending degradation that fires after shutdown', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();
        plugin.reportDegraded();

        await plugin.shutdown();
        await plugin.clock.firePendingDelays();

        expect(plugin.currentStatus, const PluginStopped());
      });

      test('markDegraded after shutdown is a no-op and schedules no timer', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();

        await plugin.shutdown();
        plugin.reportDegraded();

        expect(plugin.clock.pendingDelayDurations, isEmpty);
        expect(plugin.currentStatus, const PluginStopped());
      });

      test('markDegraded after a terminal failure schedules no timer', () async {
        final plugin = _SteadyPlugin();
        plugin.reportReady();
        plugin.reportFailed('backend gone');

        plugin.reportDegraded();

        expect(plugin.clock.pendingDelayDurations, isEmpty);
        expect(plugin.currentStatus, const PluginFailed(reason: 'backend gone'));
      });

      test('reaches Stopped even when onShutdown throws', () async {
        final plugin = _SteadyPlugin(throwOnShutdown: true);
        plugin.reportReady();

        await expectLater(plugin.shutdown(), throwsStateError);
        expect(plugin.currentStatus, const PluginStopped());
      });
    });
  });
}

class _SteadyPlugin with SteadyPluginLifecycle {
  _SteadyPlugin({this.throwOnShutdown = false});

  final bool throwOnShutdown;
  final _ManualClock clock = _ManualClock(DateTime.utc(2026, 6, 11, 12));
  int onShutdownCalls = 0;
  Duration? lastBudget;

  Duration get degradedDebounceForTest => degradedDebounce;

  void reportReady() => markReady();

  void reportDegraded({bool recoverable = true, bool requiresUserAction = false, String? userActionHint}) {
    markDegraded(recoverable: recoverable, requiresUserAction: requiresUserAction, userActionHint: userActionHint);
  }

  void reportFailed(String reason, {Object? cause}) => markFailed(reason, cause: cause);

  @override
  ServerClock get statusClock => clock;

  @override
  BridgePluginApi get api => throw UnsupportedError('api is not exercised in this test');

  @override
  PluginDiagnostics describe() => const PluginDiagnostics(pluginId: 'steady-test');

  @override
  Future<void> onShutdown({Duration? budget}) async {
    onShutdownCalls++;
    lastBudget = budget;
    if (throwOnShutdown) {
      throw StateError('teardown failed');
    }
  }
}

class _ManualClock extends ServerClock {
  _ManualClock(this._now);

  DateTime _now;
  final List<({Duration duration, Completer<void> completer})> _pendingDelays = [];

  List<Duration> get pendingDelayDurations => [for (final pending in _pendingDelays) pending.duration];

  @override
  DateTime now() => _now;

  @override
  Future<void> delay({required Duration duration}) {
    final completer = Completer<void>();
    _pendingDelays.add((duration: duration, completer: completer));
    return completer.future;
  }

  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  Future<void> firePendingDelays() async {
    final pending = List.of(_pendingDelays);
    _pendingDelays.clear();
    for (final delay in pending) {
      delay.completer.complete();
    }
    await pumpEventQueue();
  }
}
