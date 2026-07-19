import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../tool/benchmarks/benchmark_plugin_runtime.dart";

void main() {
  test("benchmark runtime rejects duplicate plugin ids", () {
    final plugin = _FakePluginApi(id: "one");

    expect(
      () => createBenchmarkPluginRuntime(plugins: [plugin, plugin]),
      throwsArgumentError,
    );
  });

  test("benchmark runtime reports supplied plugins as start allowed", () {
    final runtime = createBenchmarkPluginRuntime(
      plugins: [
        _FakePluginApi(id: "one"),
        _FakePluginApi(id: "two"),
      ],
    );
    addTearDown(runtime.dispose);

    expect(runtime.startAllowedPluginIds, {"one", "two"});
  });
}

class _FakePluginApi extends NativeProjectsPluginApi {
  _FakePluginApi({required this.id});

  @override
  final String id;

  @override
  Stream<BridgeSseEvent> get events => const Stream<BridgeSseEvent>.empty();

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
