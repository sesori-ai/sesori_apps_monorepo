import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("BridgePlugin default work-state stream replays without closing", () async {
    final plugin = _DefaultWorkStatePlugin();
    final values = <PluginWorkState>[];
    var completed = false;
    final subscription = plugin.workState.listen(values.add, onDone: () => completed = true);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);

    expect(values, [PluginWorkState.unknown]);
    expect(completed, isFalse);
  });

  test("PluginWorkStateController replays updates to later listeners", () async {
    final controller = PluginWorkStateController(initial: PluginWorkState.unknown);
    addTearDown(controller.close);

    controller.set(PluginWorkState.busy);

    expect(await controller.stream.first, PluginWorkState.busy);
  });

  test("PluginWorkStateController concurrent close callers share completion", () async {
    final controller = PluginWorkStateController(initial: PluginWorkState.idle);

    final first = controller.close();
    final second = controller.close();

    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
  });
}

class _DefaultWorkStatePlugin extends BridgePlugin {
  @override
  PluginWorkState get currentWorkState => PluginWorkState.unknown;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
