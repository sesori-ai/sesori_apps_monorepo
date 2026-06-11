import "package:sesori_bridge/src/bridge/runtime/plugin_failure_latch.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginFailed;
import "package:test/test.dart";

void main() {
  group("PluginFailureLatch", () {
    test("latches the first failure and ignores later ones", () {
      final latch = PluginFailureLatch();

      latch.record(const PluginFailed(reason: "runtime exited", cause: null));
      latch.record(const PluginFailed(reason: "second failure", cause: null));

      expect(latch.failure?.reason, "runtime exited");
    });

    test("fires the bound reaction when a failure arrives after binding", () {
      final latch = PluginFailureLatch();
      final reactions = <PluginFailed>[];
      latch.bind(reactions.add);

      latch.record(const PluginFailed(reason: "runtime exited", cause: null));

      expect(reactions.map((failure) => failure.reason), ["runtime exited"]);
    });

    test("fires immediately when binding after the failure was latched", () {
      final latch = PluginFailureLatch();
      latch.record(const PluginFailed(reason: "runtime exited", cause: null));

      final reactions = <PluginFailed>[];
      latch.bind(reactions.add);

      expect(reactions.map((failure) => failure.reason), ["runtime exited"]);
    });

    test("reacts at most once for a single latched failure", () {
      final latch = PluginFailureLatch();
      final reactions = <PluginFailed>[];
      latch.bind(reactions.add);

      latch.record(const PluginFailed(reason: "runtime exited", cause: null));
      latch.record(const PluginFailed(reason: "noise", cause: null));

      expect(reactions, hasLength(1));
    });
  });
}
