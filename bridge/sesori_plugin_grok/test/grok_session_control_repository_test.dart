import "package:acp_plugin/acp_plugin.dart";
import "package:grok_plugin/src/api/grok_acp_api.dart";
import "package:grok_plugin/src/api/models/grok_protocol_dto.dart";
import "package:grok_plugin/src/models/grok_subagent_status.dart";
import "package:grok_plugin/src/repositories/grok_session_control_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const client = _FakeAcpStdioClient();

  GrokSubagentCancelResponseDto response({
    required GrokSubagentCancelOutcomeKind kind,
    required bool cancelled,
    required GrokSubagentStatus? status,
  }) => GrokSubagentCancelResponseDto(
    subagentId: "child",
    cancelled: cancelled,
    outcome: GrokSubagentCancelOutcomeDto(kind: kind, status: status),
  );

  Future<AcpChildCancelResult> cancel({required GrokSubagentCancelResponseDto response}) =>
      GrokSessionControlRepository(api: _FakeGrokAcpApi(cancellation: () async => response)).cancelChild(
        client: client,
        parentSessionId: "parent",
        childSessionId: "child",
      );

  test("maps consistent cancelled and already-finished outcomes", () async {
    expect(
      await cancel(
        response: response(
          kind: GrokSubagentCancelOutcomeKind.cancelled,
          cancelled: true,
          status: null,
        ),
      ),
      AcpChildCancelResult.interrupted,
    );
    expect(
      await cancel(
        response: response(
          kind: GrokSubagentCancelOutcomeKind.alreadyFinished,
          cancelled: false,
          status: GrokSubagentStatus.completed,
        ),
      ),
      AcpChildCancelResult.interrupted,
    );
  });

  test("rejects cancellation kind and cancelled inconsistencies", () async {
    for (final invalidResponse in [
      response(
        kind: GrokSubagentCancelOutcomeKind.cancelled,
        cancelled: false,
        status: null,
      ),
      response(
        kind: GrokSubagentCancelOutcomeKind.alreadyFinished,
        cancelled: true,
        status: GrokSubagentStatus.completed,
      ),
      response(
        kind: GrokSubagentCancelOutcomeKind.unknown,
        cancelled: false,
        status: null,
      ),
    ]) {
      await expectLater(
        cancel(response: invalidResponse),
        throwsA(
          isA<PluginOperationException>()
              .having((error) => error.operation, "operation", GrokAcpApi.subagentCancelMethod)
              .having((error) => error.cause, "cause", isA<FormatException>()),
        ),
      );
    }
  });

  test("rejects an unknown terminal status", () async {
    await expectLater(
      cancel(
        response: response(
          kind: GrokSubagentCancelOutcomeKind.alreadyFinished,
          cancelled: false,
          status: GrokSubagentStatus.unknown,
        ),
      ),
      throwsA(
        isA<PluginOperationException>().having(
          (error) => error.cause,
          "cause",
          isA<FormatException>().having(
            (error) => error.message,
            "message",
            "Grok sub-agent cancellation returned an unknown terminal status",
          ),
        ),
      ),
    );
  });

  test("wraps transport failures with parent-child context and original cause", () async {
    final cause = StateError("transport failed");
    final repository = GrokSessionControlRepository(
      api: _FakeGrokAcpApi(cancellation: () async => throw cause),
    );

    await expectLater(
      repository.cancelChild(
        client: client,
        parentSessionId: "parent",
        childSessionId: "child",
      ),
      throwsA(
        isA<PluginOperationException>()
            .having((error) => error.cause, "cause", same(cause))
            .having(
              (error) => error.message,
              "message",
              "Grok child cancellation failed for child child under parent parent",
            ),
      ),
    );
  });
}

class _FakeGrokAcpApi({
  required final Future<GrokSubagentCancelResponseDto> Function() cancellation,
}) implements GrokAcpApi {
  @override
  Future<GrokSubagentCancelResponseDto> cancelSubagent({
    required AcpStdioClient client,
    required String subagentId,
  }) => cancellation();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _FakeAcpStdioClient() implements AcpStdioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
