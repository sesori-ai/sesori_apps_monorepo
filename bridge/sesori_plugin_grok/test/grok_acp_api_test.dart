import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:grok_plugin/src/api/grok_acp_api.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginAuthenticationRequiredException;
import "package:test/test.dart";

void main() {
  test("catalog probe authenticates only through an advertised headless method", () async {
    final fake = FakeAcpProcess();
    addTearDown(fake.close);
    final api = _api(processFactory: (_) async => fake);

    final probing = api.probeCatalog(cwd: "/repo", timeout: const Duration(seconds: 2));
    final initialize = await _waitForFrame(fake: fake, method: AcpMethods.initialize);
    fake.emit({
      "jsonrpc": "2.0",
      "id": initialize["id"],
      "result": _initializeResult(
        authMethods: const [
          {"id": "grok.com", "name": "Interactive login"},
          {"id": "cached_token", "name": "Cached token"},
        ],
      ),
    });
    final authenticate = await _waitForFrame(fake: fake, method: AcpMethods.authenticate);
    expect(authenticate["params"], {"methodId": "cached_token"});
    fake.emit({"jsonrpc": "2.0", "id": authenticate["id"], "result": <String, dynamic>{}});

    expect((await probing).raw["_meta"], {"grokShell": true, "modelState": _emptyModelState});
  });

  test("catalog probe rejects interactive-only authentication before calling it", () async {
    final fake = FakeAcpProcess();
    addTearDown(fake.close);
    final api = _api(processFactory: (_) async => fake);

    final probing = api.probeCatalog(cwd: "/repo", timeout: const Duration(seconds: 2));
    final initialize = await _waitForFrame(fake: fake, method: AcpMethods.initialize);
    fake.emit({
      "jsonrpc": "2.0",
      "id": initialize["id"],
      "result": _initializeResult(
        authMethods: const [
          {"id": "grok.com", "name": "Interactive login"},
        ],
      ),
    });

    await expectLater(probing, throwsA(isA<PluginAuthenticationRequiredException>()));
    expect(fake.written.where((frame) => frame["method"] == AcpMethods.authenticate), isEmpty);
  });

  test("catalog probe preserves an advertised authentication rejection", () async {
    final fake = FakeAcpProcess();
    addTearDown(fake.close);
    final api = _api(processFactory: (_) async => fake);

    final probing = api.probeCatalog(cwd: "/repo", timeout: const Duration(seconds: 2));
    final initialize = await _waitForFrame(fake: fake, method: AcpMethods.initialize);
    fake.emit({
      "jsonrpc": "2.0",
      "id": initialize["id"],
      "result": _initializeResult(
        authMethods: const [
          {"id": "cached_token", "name": "Cached token"},
        ],
      ),
    });
    final authenticate = await _waitForFrame(fake: fake, method: AcpMethods.authenticate);
    fake.emit({
      "jsonrpc": "2.0",
      "id": authenticate["id"],
      "error": {"code": -32000, "message": "Rejected"},
    });

    await expectLater(
      probing,
      throwsA(
        isA<PluginAuthenticationRequiredException>().having(
          (error) => error.cause,
          "cause",
          isA<AcpRpcException>(),
        ),
      ),
    );
    expect(await fake.exitCode, -15);
  });

  test("setModel sends exact model and optional reasoning metadata", () async {
    final fake = FakeAcpProcess();
    final client = AcpStdioClient(
      launchSpec: const AcpLaunchSpec(command: "grok", args: []),
      processFactory: (_) async => fake,
    );
    addTearDown(() async {
      await client.dispose();
      await fake.close();
    });
    await client.connect();
    final api = _api(processFactory: (_) => throw StateError("unused"));

    final withEffort = api.setModel(
      liveClient: client,
      sessionId: "s1",
      modelId: "opaque/provider:model-alpha",
      reasoningEffort: "high",
      timeout: const Duration(seconds: 2),
    );
    final first = await _waitForFrame(fake: fake, method: GrokAcpApi.sessionSetModelMethod);
    expect(first["params"], {
      "sessionId": "s1",
      "modelId": "opaque/provider:model-alpha",
      "_meta": {"reasoningEffort": "high"},
    });
    fake.emit({"jsonrpc": "2.0", "id": first["id"], "result": <String, dynamic>{}});
    await withEffort;

    final modelOnly = api.setModel(
      liveClient: client,
      sessionId: "s1",
      modelId: "model-beta",
      reasoningEffort: null,
      timeout: const Duration(seconds: 2),
    );
    final second = await _waitForFrame(
      fake: fake,
      method: GrokAcpApi.sessionSetModelMethod,
      afterId: first["id"],
    );
    expect(second["params"], {"sessionId": "s1", "modelId": "model-beta"});
    fake.emit({"jsonrpc": "2.0", "id": second["id"], "result": <String, dynamic>{}});
    await modelOnly;
  });
}

const Map<String, dynamic> _emptyModelState = {
  "currentModelId": null,
  "availableModels": <Object?>[],
};

Map<String, dynamic> _initializeResult({required List<Map<String, dynamic>> authMethods}) => {
  "protocolVersion": 1,
  "agentCapabilities": <String, dynamic>{},
  "authMethods": authMethods,
  "_meta": {"grokShell": true, "modelState": _emptyModelState},
};

GrokAcpApi _api({required AcpProcessFactory processFactory}) => GrokAcpApi(
  binaryPath: "grok",
  processFactory: processFactory,
  environment: const {},
);

Future<Map<String, dynamic>> _waitForFrame({
  required FakeAcpProcess fake,
  required String method,
  Object? afterId,
}) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    for (final frame in fake.written) {
      if (frame["method"] == method && frame["id"] != afterId) return frame;
    }
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError("agent never received '$method'");
}
