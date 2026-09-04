import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class _AbortAfterInitializeSignal() implements StartAbortSignal {
  int _polls = 0;

  @override
  bool get isAborted => ++_polls >= 4;

  @override
  Future<void> get whenAborted => Completer<void>().future;
}

void main() {
  late FakeAcpProcess process;
  late List<AcpLaunchSpec> launchSpecs;
  late AntigravityAcpApi api;

  setUp(() {
    process = FakeAcpProcess();
    launchSpecs = [];
    api = AntigravityAcpApi(
      processFactory: (spec) async {
        launchSpecs.add(spec);
        return process;
      },
    );
  });
  tearDown(() => process.close());

  Future<Map<String, dynamic>> waitForInitialize() async {
    for (var attempt = 0; attempt < 400; attempt++) {
      final frames = process.written.where((frame) => frame["method"] == "initialize");
      if (frames.isNotEmpty) return frames.last;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError("agent never received initialize");
  }

  Future<AntigravityInitializeDto> probe({required Duration timeout, required StartAbortSignal abortSignal}) =>
      api.initializeOnly(
        launchSpec: const AcpLaunchSpec(command: "/runtime/agy_acp_server.par", args: []),
        timeout: timeout,
        abortSignal: abortSignal,
      );

  Map<String, dynamic> initializeResult() => {
    "protocolVersion": 1,
    "agentInfo": {
      "name": "antigravity-acp",
      "title": "Google Antigravity",
      "version": AntigravityRelease.agentVersion,
    },
    "agentCapabilities": {
      "loadSession": true,
      "sessionCapabilities": {"list": <String, dynamic>{}, "resume": <String, dynamic>{}},
      "auth": {"logout": <String, dynamic>{}},
    },
    "authMethods": [
      {"id": "oauth-personal", "name": "Log in with Google"},
    ],
  };

  test("runs initialize-only and cleans up without authenticating", () async {
    final probing = probe(timeout: const Duration(seconds: 2), abortSignal: StartAbortSignal.never);
    final initialize = await waitForInitialize();
    process.emit({"jsonrpc": "2.0", "id": initialize["id"], "result": initializeResult()});

    final result = await probing;
    expect(launchSpecs.single.command, "/runtime/agy_acp_server.par");
    expect((result.agentInfo?.name, result.authMethods?.single.id), ("antigravity-acp", "oauth-personal"));
    expect(process.written.where((frame) => frame["method"] == "authenticate"), isEmpty);
    expect(await process.exitCode, -15);
  });

  test("surfaces malformed initialize data and cleans up", () async {
    final probing = probe(timeout: const Duration(seconds: 2), abortSignal: StartAbortSignal.never);
    final initialize = await waitForInitialize();
    process.emit({
      "jsonrpc": "2.0",
      "id": initialize["id"],
      "result": {...initializeResult(), "protocolVersion": "invalid"},
    });
    await expectLater(probing, throwsA(isA<TypeError>()));
    expect(await process.exitCode, -15);
  });

  test("bounds an unresponsive initialize request", () async {
    final probing = probe(timeout: const Duration(milliseconds: 250), abortSignal: StartAbortSignal.never);
    await waitForInitialize();
    await expectLater(probing, throwsA(isA<TimeoutException>()));
    expect(await process.exitCode, -15);
  });

  test("aborts an in-flight initialize and cleans up", () async {
    final controller = StartAbortController();
    final probing = probe(timeout: const Duration(seconds: 2), abortSignal: controller.signal);
    await waitForInitialize();
    controller.abort();
    await expectLater(probing, throwsA(isA<PluginStartAbortedException>()));
    expect(await process.exitCode, -15);
  });

  test("rechecks cancellation after initialize completes", () async {
    final probing = probe(
      timeout: const Duration(seconds: 2),
      abortSignal: _AbortAfterInitializeSignal(),
    );
    final initialize = await waitForInitialize();
    process.emit({"jsonrpc": "2.0", "id": initialize["id"], "result": initializeResult()});
    await expectLater(probing, throwsA(isA<PluginStartAbortedException>()));
    expect(await process.exitCode, -15);
  });

  test("preserves process-exit context and cleans up", () async {
    final probing = probe(timeout: const Duration(seconds: 2), abortSignal: StartAbortSignal.never);
    await waitForInitialize();
    process.exit(23);
    await expectLater(
      probing,
      throwsA(isA<AcpRpcException>().having((error) => error.message, "message", contains("23"))),
    );
    expect(await process.exitCode, 23);
  });
}
