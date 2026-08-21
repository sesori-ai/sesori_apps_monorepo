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
      final configurationTracker = AcpSessionConfigurationTracker();
      final commandTracker = AcpCommandTracker();
      plugin = TestAcpPlugin(
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(command: "/opt/agent", args: ["-e", "https://user:secret@host/api", "acp"]),
        launchDirectory: "/repo",
        eventMapper: AcpEventMapper(
          launchDirectory: "/repo",
          pluginId: "acp",
          configurationTracker: configurationTracker,
        ),
        commandTracker: commandTracker,
        sessionOptionsService: AcpSessionOptionsService(
          configurationTracker: configurationTracker,
          commandTracker: commandTracker,
          pluginId: "acp",
          agentDisplayName: "ACP",
        ),
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

    test("start rolls back as soon as the start is aborted during a hanging handshake", () async {
      final controller = StartAbortController();
      final stopwatch = Stopwatch()..start();
      final starting = AcpBridgePlugin.start(
        plugin: plugin,
        host: _Host(startAborted: controller.signal),
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

class _Host({@override required final StartAbortSignal startAborted}) implements PluginHost {
  @override
  ServerClock get clock => const ServerClock();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
