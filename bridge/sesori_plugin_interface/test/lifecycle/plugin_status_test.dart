import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('PluginStatus.canTransitionTo', () {
    const starting = PluginStarting();
    const ready = PluginReady();
    final degraded = PluginDegraded(since: DateTime.utc(2026, 6, 11));
    const restarting = PluginRestarting(attempt: 1);
    const failed = PluginFailed(reason: 'runtime exited');
    const stopping = PluginStopping();
    const stopped = PluginStopped();

    Set<Type> allowedTargets(PluginStatus from) {
      final all = <PluginStatus>[starting, ready, degraded, restarting, failed, stopping, stopped];
      return all.where(from.canTransitionTo).map((status) => status.runtimeType).toSet();
    }

    test('Starting may become Ready, Degraded, Failed, or Stopping', () {
      expect(allowedTargets(starting), {PluginReady, PluginDegraded, PluginFailed, PluginStopping});
    });

    test('Ready may become Degraded, Restarting, Failed, or Stopping', () {
      expect(allowedTargets(ready), {PluginDegraded, PluginRestarting, PluginFailed, PluginStopping});
    });

    test('Degraded may become Ready, Degraded, Restarting, Failed, or Stopping', () {
      expect(allowedTargets(degraded), {
        PluginReady,
        PluginDegraded,
        PluginRestarting,
        PluginFailed,
        PluginStopping,
      });
    });

    test('Restarting may become Ready, Degraded, Restarting, Failed, or Stopping', () {
      expect(allowedTargets(restarting), {
        PluginReady,
        PluginDegraded,
        PluginRestarting,
        PluginFailed,
        PluginStopping,
      });
    });

    test('Failed may only become Stopping', () {
      expect(allowedTargets(failed), {PluginStopping});
    });

    test('Stopping may only become Stopped', () {
      expect(allowedTargets(stopping), {PluginStopped});
    });

    test('Stopped is terminal', () {
      expect(allowedTargets(stopped), isEmpty);
    });

    test('Failed can never follow Stopping or Stopped', () {
      expect(stopping.canTransitionTo(failed), isFalse);
      expect(stopped.canTransitionTo(failed), isFalse);
    });
  });

  group('PluginStatus equality', () {
    test('stateless statuses compare equal across instances', () {
      expect(const PluginStarting(), const PluginStarting());
      expect(const PluginReady(), const PluginReady());
      expect(const PluginStopping(), const PluginStopping());
      expect(const PluginStopped(), const PluginStopped());
      expect(const PluginReady(), isNot(const PluginStarting()));
    });

    test('Degraded compares by all fields', () {
      final since = DateTime.utc(2026, 6, 11, 10);
      final a = PluginDegraded(since: since, requiresUserAction: true, userActionHint: 're-authenticate');
      final b = PluginDegraded(since: since, requiresUserAction: true, userActionHint: 're-authenticate');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(PluginDegraded(since: since)));
      expect(
        a,
        isNot(
          PluginDegraded(since: DateTime.utc(2026, 6, 12), requiresUserAction: true, userActionHint: 're-authenticate'),
        ),
      );
    });

    test('Restarting compares by attempt and reason', () {
      expect(
        const PluginRestarting(attempt: 2, reason: 'exit 1'),
        const PluginRestarting(attempt: 2, reason: 'exit 1'),
      );
      expect(const PluginRestarting(attempt: 2), isNot(const PluginRestarting(attempt: 3)));
    });

    test('Failed compares by reason and cause', () {
      expect(const PluginFailed(reason: 'gone'), const PluginFailed(reason: 'gone'));
      expect(const PluginFailed(reason: 'gone'), isNot(const PluginFailed(reason: 'gone', cause: 'socket')));
    });
  });
}
