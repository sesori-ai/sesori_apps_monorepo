import "dart:async";
import "dart:convert";
import "dart:io";

import "package:opencode_plugin/src/runtime/open_code_device_canvas_tools.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("OpenCode Device Canvas tools", () {
    test("generates exactly three dependency-free tools bound to the trusted invocation context", () {
      final source = buildOpenCodeDeviceCanvasToolPluginSource();
      final definitions = RegExp(
        r"^      (list_simulators|claim_simulator|release_simulator): \{$",
        multiLine: true,
      ).allMatches(source);

      expect(definitions.map((match) => match.group(1)), [
        "list_simulators",
        "claim_simulator",
        "release_simulator",
      ]);
      expect(source, isNot(contains("@opencode-ai/plugin")));
      expect(source, isNot(contains("tool.schema")));
      expect(RegExp(r"backendSessionId: context\.sessionID").allMatches(source), hasLength(3));
      expect(source, isNot(contains("args.sessionId")));
      expect(source, isNot(contains("args.bridgeId")));
      expect(source, isNot(contains("force")));
      expect(RegExp(r"context\.abort").allMatches(source), hasLength(3));
      expect(source, contains("registrationPromise ??="));
      expect(source, contains('await writeFile(readyFilePath, "ready")'));
      expect(source, contains("delete process.env[bootstrapFileEnvironment]"));
      expect(source, contains("delete output.env[bootstrapFileEnvironment]"));
      expect(source, contains("await unlink(bootstrapFilePath)"));
      expect(source, isNot(contains(deviceCanvasAgentToolBootstrapSecretEnvironment)));
    });

    test("prepares a managed config layer and scopes credentials to a successful injection", () async {
      final tempDirectory = await Directory.systemTemp.createTemp("opencode-device-canvas-tools-");
      addTearDown(() => tempDirectory.delete(recursive: true));
      final host = _FakeHost(
        stateDirectory: tempDirectory.path,
        environment: const <String, String>{
          deviceCanvasAgentToolBootstrapSecretEnvironment: "bootstrap",
          deviceCanvasAgentToolRendezvousEnvironment: "/runtime/rendezvous.json",
        },
      );

      final overrides = await configureOpenCodeDeviceCanvasTools(host: host);

      expect(overrides[deviceCanvasAgentToolBootstrapSecretEnvironment], "bootstrap");
      expect(
        overrides[deviceCanvasAgentToolBootstrapFileEnvironment],
        "${tempDirectory.path}/sesori-device-canvas-tools.bootstrap",
      );
      expect(overrides[deviceCanvasAgentToolRendezvousEnvironment], "/runtime/rendezvous.json");
      expect(overrides[deviceCanvasAgentToolReadyFileEnvironment], endsWith("sesori-device-canvas-tools.ready"));
      final inlineConfig = jsonDecode(overrides["OPENCODE_CONFIG_CONTENT"]!) as Map<String, dynamic>;
      expect(inlineConfig["plugin"], [Uri.file("${tempDirectory.path}/sesori-device-canvas-tools.js").toString()]);
      expect(host.store.files[openCodeDeviceCanvasToolPluginFileName], buildOpenCodeDeviceCanvasToolPluginSource());
      expect(host.store.files, isNot(contains("opencode.json")));
    });

    test("adds an external config layer without replacing existing inline config", () async {
      final tempDirectory = await Directory.systemTemp.createTemp("opencode-device-canvas-inline-");
      addTearDown(() => tempDirectory.delete(recursive: true));
      final host = _FakeHost(
        stateDirectory: tempDirectory.path,
        environment: const <String, String>{
          deviceCanvasAgentToolBootstrapSecretEnvironment: "bootstrap",
          deviceCanvasAgentToolRendezvousEnvironment: "/runtime/rendezvous.json",
          "OPENCODE_CONFIG_CONTENT": '{"model":"test/model"}',
        },
      );

      final overrides = await configureOpenCodeDeviceCanvasTools(host: host);

      expect(overrides, isNot(contains("OPENCODE_CONFIG_CONTENT")));
      expect(overrides["OPENCODE_CONFIG"], "${tempDirectory.path}/sesori-device-canvas-tools.json");
      expect(host.store.files, contains(openCodeDeviceCanvasToolPluginFileName));
      expect(host.store.files, contains("sesori-device-canvas-tools.json"));
    });

    test("fails closed when config injection or scoped credentials are unavailable", () async {
      final tempDirectory = await Directory.systemTemp.createTemp("opencode-device-canvas-closed-");
      addTearDown(() => tempDirectory.delete(recursive: true));
      final conflicting = _FakeHost(
        stateDirectory: tempDirectory.path,
        environment: const <String, String>{
          deviceCanvasAgentToolBootstrapSecretEnvironment: "bootstrap",
          deviceCanvasAgentToolRendezvousEnvironment: "/runtime/rendezvous.json",
          "OPENCODE_CONFIG": "/custom/opencode.json",
          "OPENCODE_CONFIG_CONTENT": "{}",
        },
      );
      final missingCredentials = _FakeHost(
        stateDirectory: tempDirectory.path,
        environment: const <String, String>{},
      );

      expect(await configureOpenCodeDeviceCanvasTools(host: conflicting), isEmpty);
      expect(conflicting.store.files, isEmpty);
      expect(await configureOpenCodeDeviceCanvasTools(host: missingCredentials), isEmpty);
      expect(missingCredentials.store.files, isEmpty);
    });
  });
}

class _FakeHost({
  @override required final String stateDirectory,
  @override required final Map<String, String> environment,
}) implements PluginHost {
  @override
  final _MemoryJsonStore store = _MemoryJsonStore();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError("Unexpected call: ${invocation.memberName}");
}

class _MemoryJsonStore() implements HostJsonStore {
  final Map<String, String> files = <String, String>{};

  @override
  Future<String?> read({required String name}) async => files[name];

  @override
  Future<void> write({required String name, required String contents}) async {
    files[name] = contents;
  }

  @override
  Future<void> delete({required String name}) async {
    files.remove(name);
  }

  @override
  Future<void> quarantine({required String name, required String quarantinedName}) async {
    final contents = files.remove(name);
    if (contents != null) files[quarantinedName] = contents;
  }

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    final next = await transform(files[name]);
    if (next == null) {
      files.remove(name);
    } else {
      files[name] = next;
    }
    return next;
  }
}
