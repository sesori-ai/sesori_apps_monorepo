import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('PluginStatusController', () {
    test('starts as Starting by default', () {
      final controller = PluginStatusController(initial: const PluginStarting());
      expect(controller.current, const PluginStarting());
      expect(controller.isClosed, isFalse);
    });

    test('replays the current status to every new listener', () async {
      final controller = PluginStatusController(initial: const PluginStarting());
      controller.set(const PluginReady());

      expect(await controller.stream.first, const PluginReady());
      expect(await controller.stream.first, const PluginReady());
    });

    test('delivers replay followed by live updates, in order', () async {
      final controller = PluginStatusController(initial: const PluginStarting());
      final seen = <PluginStatus>[];
      final subscription = controller.stream.listen(seen.add);

      controller.set(const PluginReady());
      controller.set(const PluginStopping());
      await pumpEventQueue();

      expect(seen, [const PluginStarting(), const PluginReady(), const PluginStopping()]);
      await subscription.cancel();
    });

    test('supports multiple simultaneous listeners', () async {
      final controller = PluginStatusController(initial: const PluginStarting());
      final first = <PluginStatus>[];
      final second = <PluginStatus>[];
      final subscriptionA = controller.stream.listen(first.add);
      final subscriptionB = controller.stream.listen(second.add);

      controller.set(const PluginReady());
      await pumpEventQueue();

      expect(first, [const PluginStarting(), const PluginReady()]);
      expect(second, [const PluginStarting(), const PluginReady()]);
      await subscriptionA.cancel();
      await subscriptionB.cancel();
    });

    test('set throws StateError on an illegal transition and keeps the current status', () {
      final controller = PluginStatusController(initial: const PluginStarting());
      controller.set(const PluginStopping());

      expect(() => controller.set(const PluginReady()), throwsStateError);
      expect(controller.current, const PluginStopping());
    });

    test('trySet drops an illegal transition silently', () async {
      final controller = PluginStatusController(initial: const PluginStarting());
      controller.set(const PluginStopping());
      final seen = <PluginStatus>[];
      final subscription = controller.stream.listen(seen.add);

      final accepted = controller.trySet(const PluginFailed(reason: 'exit monitor fired during stop', cause: null));
      await pumpEventQueue();

      expect(accepted, isFalse);
      expect(controller.current, const PluginStopping());
      expect(seen, [const PluginStopping()]);
      await subscription.cancel();
    });

    test('no Failed after Stopping', () {
      final controller = PluginStatusController(initial: const PluginStarting());
      controller.set(const PluginStopping());

      expect(controller.trySet(const PluginFailed(reason: 'late', cause: null)), isFalse);
      expect(controller.current, const PluginStopping());
    });

    test('setting a status equal to the current one is a silent no-op', () async {
      final controller = PluginStatusController(initial: const PluginStarting());
      controller.set(const PluginReady());
      final seen = <PluginStatus>[];
      final subscription = controller.stream.listen(seen.add);

      expect(controller.trySet(const PluginReady()), isTrue);
      await pumpEventQueue();

      expect(seen, [const PluginReady()]);
      await subscription.cancel();
    });

    test('Degraded can be refreshed with new details', () async {
      final controller = PluginStatusController(initial: const PluginStarting());
      final since = DateTime.utc(2026, 6, 11);
      controller.set(PluginDegraded(since: since, recoverable: true, requiresUserAction: false, userActionHint: null));

      controller.set(
        PluginDegraded(since: since, recoverable: true, requiresUserAction: true, userActionHint: 'log in again'),
      );

      final current = controller.current;
      expect(current, isA<PluginDegraded>());
      expect((current as PluginDegraded).userActionHint, 'log in again');
    });

    test('closes active listeners after Stopped', () async {
      final controller = PluginStatusController(initial: const PluginStarting());
      final seen = <PluginStatus>[];
      var done = false;
      controller.stream.listen(seen.add, onDone: () => done = true);

      controller.set(const PluginStopping());
      controller.set(const PluginStopped());
      await pumpEventQueue();

      expect(seen, [const PluginStarting(), const PluginStopping(), const PluginStopped()]);
      expect(done, isTrue);
      expect(controller.isClosed, isTrue);
    });

    test('a late listener still receives Stopped followed by done', () async {
      final controller = PluginStatusController(initial: const PluginStarting());
      controller.set(const PluginStopping());
      controller.set(const PluginStopped());

      final events = await controller.stream.toList();
      expect(events, [const PluginStopped()]);
    });

    test('trySet after Stopped accepts only the equal value no-op', () {
      final controller = PluginStatusController(initial: const PluginStarting());
      controller.set(const PluginStopping());
      controller.set(const PluginStopped());

      expect(controller.trySet(const PluginStopped()), isTrue);
      expect(controller.trySet(const PluginReady()), isFalse);
    });

    test('honors a custom initial status', () {
      final controller = PluginStatusController(initial: const PluginReady());
      expect(controller.current, const PluginReady());
    });
  });
}
