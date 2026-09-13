import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:antigravity_plugin/src/api/models/antigravity_version_dto.dart";
import "package:antigravity_plugin/src/models/antigravity_runtime_version.dart";
import "package:antigravity_plugin/src/repositories/antigravity_runtime_version_repository.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class const _UnusedCommands() implements CommandExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VersionApi({required final Future<AntigravityVersionDto> Function() outcome}) extends AntigravityAcpApi {
  this
    : super(
        commands: const _UnusedCommands(),
        processFactory: (_) async => throw UnimplementedError(),
        stderrInterceptor: AcpOutputInterceptor(maxLineBytes: 1, consumeLine: ({required line}) => false),
      );

  @override
  Future<AntigravityVersionDto> version({
    required String serverPath,
    required Map<String, String> environment,
    required Duration timeout,
  }) => outcome();
}

void main() {
  const source = AntigravityRuntimeSource.path;

  Future<AntigravityRuntimeVersionProbeResult> probe({
    required Future<AntigravityVersionDto> Function() outcome,
  }) => AntigravityRuntimeVersionRepository(api: _VersionApi(outcome: outcome)).probe(
    source: source,
    serverPath: "/runtime/agy_acp_server.par",
    environment: const {"GEMINI_HOME": "/isolated"},
    timeout: const Duration(seconds: 1),
  );

  test("maps a usable API DTO into a runtime-domain success", () async {
    final result = await probe(
      outcome: () async => const AntigravityVersionDto(
        exitCode: 0,
        buildLabel: AntigravityRelease.agentVersion,
      ),
    );

    expect(result, isA<AntigravityRuntimeVersionProbeSucceeded>());
    final success = result as AntigravityRuntimeVersionProbeSucceeded;
    expect((success.source, success.version), (source, AntigravityRelease.agentVersion));
  });

  test("maps nonzero and missing-label DTOs without exposing command output", () async {
    for (final dto in const [
      AntigravityVersionDto(exitCode: 23, buildLabel: AntigravityRelease.agentVersion),
      AntigravityVersionDto(exitCode: 0, buildLabel: null),
    ]) {
      final result = await probe(outcome: () async => dto);

      expect(result, isA<AntigravityRuntimeVersionProbeRejected>());
      final rejected = result as AntigravityRuntimeVersionProbeRejected;
      expect((rejected.source, rejected.exitCode), (source, dto.exitCode));
    }
  });

  test("logs an API failure locally and returns an opaque-free domain failure", () async {
    final logs = BufferingStdout();
    final previousLevel = Log.level;
    late AntigravityRuntimeVersionProbeResult result;
    try {
      Log.level = LogLevel.debug;
      await IOOverrides.runZoned(
        () async => result = await probe(outcome: () async => throw StateError("synthetic version failure")),
        stderr: () => logs,
      );
    } finally {
      Log.level = previousLevel;
    }

    expect(result, isA<AntigravityRuntimeVersionProbeFailed>());
    expect((result as AntigravityRuntimeVersionProbeFailed).source, source);
    expect(logs.text, contains("synthetic version failure"));
    expect(logs.text, contains("/runtime/agy_acp_server.par"));
  });
}
