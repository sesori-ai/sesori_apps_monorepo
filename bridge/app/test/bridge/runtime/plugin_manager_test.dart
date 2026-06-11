import "dart:async";

import "package:sesori_bridge/src/bridge/runtime/plugin_manager.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePlugin;
import "package:test/test.dart";

void main() {
  group("PluginManager", () {
    const budget = Duration(seconds: 7);

    test("startPlugin starts the registered plugin and tracks it as active", () async {
      final manager = PluginManager();
      final plugin = _FakeBridgePlugin();
      manager.register(id: "opencode", starter: () async => plugin, shutdownBudget: budget);

      final started = await manager.startPlugin(id: "opencode");

      expect(started, same(plugin));
      expect(manager.activePlugins, {"opencode": plugin});
    });

    test("startPlugin throws for an unknown id, naming the registered ones", () async {
      final manager = PluginManager();
      manager.register(id: "opencode", starter: () async => _FakeBridgePlugin(), shutdownBudget: budget);

      await expectLater(
        manager.startPlugin(id: "cursor"),
        throwsA(
          isA<StateError>().having((e) => e.message, "message", allOf(contains('"cursor"'), contains("opencode"))),
        ),
      );
    });

    test("repeated startPlugin shares one start", () async {
      final manager = PluginManager();
      var starts = 0;
      manager.register(
        id: "opencode",
        starter: () async {
          starts++;
          return _FakeBridgePlugin();
        },
        shutdownBudget: budget,
      );

      final first = await manager.startPlugin(id: "opencode");
      final second = await manager.startPlugin(id: "opencode");

      expect(starts, 1);
      expect(second, same(first));
    });

    test("startPlugin for a second id while one is active throws", () async {
      final manager = PluginManager();
      manager.register(id: "opencode", starter: () async => _FakeBridgePlugin(), shutdownBudget: budget);
      manager.register(id: "cursor", starter: () async => _FakeBridgePlugin(), shutdownBudget: budget);
      await manager.startPlugin(id: "opencode");

      await expectLater(
        manager.startPlugin(id: "cursor"),
        throwsA(isA<StateError>().having((e) => e.message, "message", contains("exactly one active plugin"))),
      );
    });

    test("startPlugin for a second id while the first is still stopping throws", () async {
      final manager = PluginManager();
      final shutdownGate = Completer<void>();
      manager.register(
        id: "opencode",
        starter: () async => _FakeBridgePlugin(shutdownGate: shutdownGate),
        shutdownBudget: budget,
      );
      manager.register(id: "cursor", starter: () async => _FakeBridgePlugin(), shutdownBudget: budget);
      await manager.startPlugin(id: "opencode");
      final stop = manager.stopPlugin(id: "opencode");

      await expectLater(
        manager.startPlugin(id: "cursor"),
        throwsA(isA<StateError>().having((e) => e.message, "message", contains("exactly one active plugin"))),
      );

      shutdownGate.complete();
      await stop;
    });

    test("a failed start untracks the id so a retry starts fresh", () async {
      final manager = PluginManager();
      var starts = 0;
      manager.register(
        id: "opencode",
        starter: () async {
          starts++;
          if (starts == 1) {
            throw StateError("boom");
          }
          return _FakeBridgePlugin();
        },
        shutdownBudget: budget,
      );

      await expectLater(manager.startPlugin(id: "opencode"), throwsA(isA<StateError>()));
      expect(manager.activePlugins, isEmpty);

      await manager.startPlugin(id: "opencode");

      expect(starts, 2);
      expect(manager.activePlugins.keys, ["opencode"]);
    });

    test("stopPlugin is a no-op when nothing runs under the id", () async {
      final manager = PluginManager();
      manager.register(id: "opencode", starter: () async => _FakeBridgePlugin(), shutdownBudget: budget);

      await manager.stopPlugin(id: "opencode");
      await manager.stopPlugin(id: "never-registered");
    });

    test("stopPlugin cancels the session before shutting the plugin down, honoring the budget", () async {
      final manager = PluginManager();
      final operations = <String>[];
      final plugin = _FakeBridgePlugin(operations: operations);
      manager.register(id: "opencode", starter: () async => plugin, shutdownBudget: budget);
      manager.bindActiveSession(
        cancel: () async {
          operations.add("session.cancel");
        },
      );
      await manager.startPlugin(id: "opencode");

      await manager.stopPlugin(id: "opencode");

      expect(operations, ["session.cancel", "shutdown"]);
      expect(plugin.shutdownBudgets, [budget]);
      expect(manager.activePlugins, isEmpty);
    });

    test("stopPlugin without a bound session goes straight to shutdown", () async {
      final manager = PluginManager();
      final plugin = _FakeBridgePlugin();
      manager.register(id: "opencode", starter: () async => plugin, shutdownBudget: budget);
      await manager.startPlugin(id: "opencode");

      await manager.stopPlugin(id: "opencode");

      expect(plugin.shutdownCalls, 1);
    });

    test("concurrent stopPlugin calls share one stop", () async {
      final manager = PluginManager();
      final plugin = _FakeBridgePlugin();
      manager.register(id: "opencode", starter: () async => plugin, shutdownBudget: budget);
      await manager.startPlugin(id: "opencode");

      final first = manager.stopPlugin(id: "opencode");
      final second = manager.stopPlugin(id: "opencode");
      await first;
      await second;

      expect(identical(first, second), isTrue);
      expect(plugin.shutdownCalls, 1);

      await manager.stopPlugin(id: "opencode");
      expect(plugin.shutdownCalls, 1, reason: "a stop after completion is a no-op, not a second shutdown");
    });

    test("stopPlugin proceeds to shutdown when the session cancel throws", () async {
      final manager = PluginManager();
      final plugin = _FakeBridgePlugin();
      manager.register(id: "opencode", starter: () async => plugin, shutdownBudget: budget);
      manager.bindActiveSession(cancel: () async => throw StateError("cancel failed"));
      await manager.startPlugin(id: "opencode");

      await manager.stopPlugin(id: "opencode");

      expect(plugin.shutdownCalls, 1);
    });

    test("stopPlugin over an in-flight start waits for the start, then stops", () async {
      final manager = PluginManager();
      final startGate = Completer<BridgePlugin>();
      final plugin = _FakeBridgePlugin();
      manager.register(id: "opencode", starter: () => startGate.future, shutdownBudget: budget);

      final start = manager.startPlugin(id: "opencode");
      final stop = manager.stopPlugin(id: "opencode");
      expect(plugin.shutdownCalls, 0);

      startGate.complete(plugin);
      await start;
      await stop;

      expect(plugin.shutdownCalls, 1);
      expect(manager.activePlugins, isEmpty);
    });

    test("stopPlugin over a failed in-flight start completes without stopping anything", () async {
      final manager = PluginManager();
      final startGate = Completer<BridgePlugin>();
      manager.register(id: "opencode", starter: () => startGate.future, shutdownBudget: budget);

      final start = manager.startPlugin(id: "opencode");
      final stop = manager.stopPlugin(id: "opencode");
      startGate.completeError(StateError("start failed"));

      await expectLater(start, throwsA(isA<StateError>()));
      await stop;
      expect(manager.activePlugins, isEmpty);
    });

    test("after a stop the id can be started fresh", () async {
      final manager = PluginManager();
      var starts = 0;
      manager.register(
        id: "opencode",
        starter: () async {
          starts++;
          return _FakeBridgePlugin();
        },
        shutdownBudget: budget,
      );

      await manager.startPlugin(id: "opencode");
      await manager.stopPlugin(id: "opencode");
      await manager.startPlugin(id: "opencode");

      expect(starts, 2);
      expect(manager.activePlugins.keys, ["opencode"]);
    });

    test("startPlugin during an in-flight stop waits for the stop, then restarts", () async {
      final manager = PluginManager();
      final shutdownGate = Completer<void>();
      var starts = 0;
      manager.register(
        id: "opencode",
        starter: () async {
          starts++;
          return starts == 1 ? _FakeBridgePlugin(shutdownGate: shutdownGate) : _FakeBridgePlugin();
        },
        shutdownBudget: budget,
      );
      await manager.startPlugin(id: "opencode");
      final stop = manager.stopPlugin(id: "opencode");

      final restart = manager.startPlugin(id: "opencode");
      expect(starts, 1, reason: "the restart must wait for the in-flight stop");

      shutdownGate.complete();
      await stop;
      await restart;

      expect(starts, 2);
      expect(manager.activePlugins.keys, ["opencode"]);
    });

    test("activePlugins excludes starting and stopping plugins", () async {
      final manager = PluginManager();
      final startGate = Completer<BridgePlugin>();
      final shutdownGate = Completer<void>();
      final plugin = _FakeBridgePlugin(shutdownGate: shutdownGate);
      manager.register(id: "opencode", starter: () => startGate.future, shutdownBudget: budget);

      final start = manager.startPlugin(id: "opencode");
      expect(manager.activePlugins, isEmpty, reason: "still starting");

      startGate.complete(plugin);
      await start;
      expect(manager.activePlugins.keys, ["opencode"]);

      final stop = manager.stopPlugin(id: "opencode");
      await Future<void>.delayed(Duration.zero);
      expect(manager.activePlugins, isEmpty, reason: "already stopping");

      shutdownGate.complete();
      await stop;
      expect(manager.activePlugins, isEmpty);
    });

    test("a synchronously throwing starter is untracked like an async failure", () async {
      final manager = PluginManager();
      var starts = 0;
      manager.register(
        id: "opencode",
        starter: () {
          starts++;
          if (starts == 1) {
            throw StateError("sync boom");
          }
          return Future.value(_FakeBridgePlugin());
        },
        shutdownBudget: budget,
      );
      manager.register(id: "cursor", starter: () async => _FakeBridgePlugin(), shutdownBudget: budget);

      await expectLater(manager.startPlugin(id: "opencode"), throwsA(isA<StateError>()));
      expect(manager.activePlugins, isEmpty);

      await manager.stopPlugin(id: "opencode");
      await manager.startPlugin(id: "opencode");
      expect(starts, 2, reason: "the failed sync start must not wedge the id");

      await manager.stopPlugin(id: "opencode");
      await manager.startPlugin(id: "cursor");
      expect(manager.activePlugins.keys, ["cursor"], reason: "other ids must not see a phantom active plugin");
    });

    test("stopPlugin rethrows a failing shutdown — the runner's loud-exit guarantee depends on it", () async {
      final manager = PluginManager();
      final plugin = _FakeBridgePlugin(shutdownError: StateError("shutdown failed"));
      manager.register(id: "opencode", starter: () async => plugin, shutdownBudget: budget);
      await manager.startPlugin(id: "opencode");

      await expectLater(manager.stopPlugin(id: "opencode"), throwsA(isA<StateError>()));
    });

    test("a failing shutdown still untracks the id: repeat stop is a no-op and a restart starts fresh", () async {
      final manager = PluginManager();
      var starts = 0;
      manager.register(
        id: "opencode",
        starter: () async {
          starts++;
          return starts == 1 ? _FakeBridgePlugin(shutdownError: StateError("shutdown failed")) : _FakeBridgePlugin();
        },
        shutdownBudget: budget,
      );
      await manager.startPlugin(id: "opencode");

      await expectLater(manager.stopPlugin(id: "opencode"), throwsA(isA<StateError>()));
      expect(manager.activePlugins, isEmpty);

      await manager.stopPlugin(id: "opencode");

      await manager.startPlugin(id: "opencode");
      expect(starts, 2);
      expect(manager.activePlugins.keys, ["opencode"]);
    });

    test("startPlugin over an in-flight stop whose shutdown fails still starts fresh", () async {
      final manager = PluginManager();
      final shutdownGate = Completer<void>();
      var starts = 0;
      manager.register(
        id: "opencode",
        starter: () async {
          starts++;
          return starts == 1
              ? _FakeBridgePlugin(shutdownGate: shutdownGate, shutdownError: StateError("shutdown failed"))
              : _FakeBridgePlugin();
        },
        shutdownBudget: budget,
      );
      await manager.startPlugin(id: "opencode");
      final stop = manager.stopPlugin(id: "opencode");

      final restart = manager.startPlugin(id: "opencode");
      shutdownGate.complete();

      await expectLater(stop, throwsA(isA<StateError>()), reason: "the stop caller owns the shutdown error");
      await restart;
      expect(starts, 2, reason: "the failed stop must not leak its error into the restart");
      expect(manager.activePlugins.keys, ["opencode"]);
    });

    test("bindActiveSession replaces the previous binding", () async {
      final manager = PluginManager();
      final operations = <String>[];
      final plugin = _FakeBridgePlugin(operations: operations);
      manager.register(id: "opencode", starter: () async => plugin, shutdownBudget: budget);
      manager.bindActiveSession(
        cancel: () async {
          operations.add("cancel.replaced");
        },
      );
      manager.bindActiveSession(
        cancel: () async {
          operations.add("cancel.latest");
        },
      );
      await manager.startPlugin(id: "opencode");

      await manager.stopPlugin(id: "opencode");

      expect(operations, ["cancel.latest", "shutdown"]);
    });

    test("register throws for a duplicate id", () {
      final manager = PluginManager();
      manager.register(id: "opencode", starter: () async => _FakeBridgePlugin(), shutdownBudget: budget);

      expect(
        () => manager.register(id: "opencode", starter: () async => _FakeBridgePlugin(), shutdownBudget: budget),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeBridgePlugin implements BridgePlugin {
  _FakeBridgePlugin({List<String>? operations, this.shutdownGate, this.shutdownError})
    : operations = operations ?? <String>[];

  final List<String> operations;
  final Completer<void>? shutdownGate;
  final Object? shutdownError;
  final List<Duration?> shutdownBudgets = [];
  int shutdownCalls = 0;

  @override
  Future<void> shutdown({required Duration? budget}) async {
    shutdownCalls++;
    shutdownBudgets.add(budget);
    operations.add("shutdown");
    await (shutdownGate?.future ?? Future<void>.value());
    if (shutdownError != null) {
      throw shutdownError!;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
