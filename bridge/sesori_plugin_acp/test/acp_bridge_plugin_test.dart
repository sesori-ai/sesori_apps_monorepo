import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("AcpBridgePlugin", () {
    late FakeAcpProcess fake;
    late TestAcpPlugin plugin;

    setUp(() {
      fake = FakeAcpProcess();
      plugin = composeTestAcpPlugin(
        launchSpec: const AcpLaunchSpec(command: "/opt/agent", args: ["-e", "https://user:secret@host/api", "acp"]),
        processFactory: (_) async => fake,
      );
    });

    tearDown(() async {
      await fake.close();
    });

    Future<void> waitForFrame(String method) async {
      for (var i = 0; i < 400; i++) {
        if (fake.written.any((frame) => frame["method"] == method)) return;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    test("describe exposes the agent executable, not its launch arguments", () async {
      final wrapper = AcpBridgePlugin(plugin: plugin, clock: const ServerClock());
      addTearDown(() => wrapper.shutdown(budget: null));
      final diagnostics = wrapper.describe();
      expect(diagnostics.endpoint, "/opt/agent");
      expect(diagnostics.details, {"transport": "acp-stdio", "agent": "ACP"});
    });

    test("authentication failure preserves required user action", () async {
      final starting = AcpBridgePlugin.start(
        plugin: plugin,
        host: _Host(startAborted: StartAbortSignal.never, clock: _ImmediateClock()),
        connectBudget: const Duration(seconds: 5),
      );
      await waitForFrame("initialize");
      final initialize = fake.written.firstWhere((frame) => frame["method"] == "initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": [
            {"id": "token", "name": "Token"},
          ],
        },
      });
      await waitForFrame("authenticate");
      final authenticate = fake.written.firstWhere((frame) => frame["method"] == "authenticate");
      fake.emit({
        "jsonrpc": "2.0",
        "id": authenticate["id"],
        "error": {"code": -32000, "message": "authentication required"},
      });

      final wrapper = await starting;
      addTearDown(() => wrapper.shutdown(budget: null));
      await Future<void>.delayed(Duration.zero);
      expect(wrapper.currentStatus, isA<PluginDegraded>());
      if (wrapper.currentStatus case PluginDegraded(:final requiresUserAction, :final userActionHint)) {
        expect(requiresUserAction, isTrue);
        expect(userActionHint, isNotEmpty);
      }
    });

    test("start rolls back as soon as the start is aborted during a hanging handshake", () async {
      final controller = StartAbortController();
      final stopwatch = Stopwatch()..start();
      final starting = AcpBridgePlugin.start(
        plugin: plugin,
        host: _Host(startAborted: controller.signal, clock: const ServerClock()),
        connectBudget: const Duration(seconds: 30),
      );
      // The agent never answers `initialize`; abort while the handshake hangs.
      await waitForFrame("initialize");
      controller.abort();

      await expectLater(starting, throwsA(isA<PluginStartAbortedException>()));
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: "the abort must not wait out the connect budget",
      );
    });
  });
}

class _Host({
  @override required final StartAbortSignal startAborted,
  @override required final ServerClock clock,
}) implements PluginHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImmediateClock() implements ServerClock {
  @override
  Future<void> delay({required Duration duration}) async {}

  @override
  DateTime now() => DateTime.utc(2026, 8, 27);
}
