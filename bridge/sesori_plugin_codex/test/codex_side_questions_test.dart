import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/models/codex_thread_sample_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_thread_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_side_answer_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CodexSideAnswerMapper", () {
    const mapper = CodexSideAnswerMapper();

    test("sample text is the answer, with no notice", () {
      expect(
        mapper.map(sample: const CodexThreadSampleDto(text: "  The answer.\n")),
        isA<PluginSideAnswered>()
            .having((answer) => answer.text, "text", "The answer.")
            .having((answer) => answer.notice, "notice", isNull),
      );
    });

    test("null or blank text is no answer", () {
      for (final text in [null, "  "]) {
        expect(mapper.map(sample: CodexThreadSampleDto(text: text)), _refused(reason: PluginSideRefusal.noAnswer));
      }
    });

    test("an old Codex without thread/sample, or one that can't sample mid-turn, needs an update", () {
      for (final message in [
        "Invalid request: unknown variant `thread/sample`, expected one of `initialize`, `thread/start`",
        "sample source must be idle",
      ]) {
        expect(mapper.mapUnsupported(error: _rpcError(message: message)), _refused(reason: PluginSideRefusal.harnessUpdateRequired));
      }
    });

    test("other errors are not a refusal", () {
      for (final message in ["sample timed out", "sample source turn must be the latest turn"]) {
        expect(mapper.mapUnsupported(error: _rpcError(message: message)), isNull);
      }
    });
  });

  group("CodexThreadRepository side questions", () {
    test("sampleThread allows a running turn and waits past Codex's own 30 s deadline", () async {
      final transport = _Transport(
        responses: [
          {"sourceTurnId": "turn-1", "responseId": "resp-1", "text": "Answer.", "inputTokens": 10},
        ],
      );

      final answer = await _repository(transport: transport).sampleThread(
        threadId: "thread-1",
        expectedTurnId: "turn-1",
        prompt: "Side question: Why?",
      );

      expect(answer, isA<PluginSideAnswered>().having((answer) => answer.text, "text", "Answer."));
      expect(transport.calls.single.method, "thread/sample");
      expect(transport.calls.single.params, {
        "threadId": "thread-1",
        "expectedTurnId": "turn-1",
        "allowInProgressTurn": true,
        "prompt": "Side question: Why?",
      });
      expect(transport.calls.single.timeout, const Duration(seconds: 40));
    });

    test("sampleThread maps an old PATH Codex to an update refusal", () async {
      final transport = _Transport(responses: [_rpcError(message: "sample source must be idle")]);

      final answer = await _repository(transport: transport).sampleThread(
        threadId: "thread-1",
        expectedTurnId: "turn-1",
        prompt: "Why?",
      );

      expect(answer, _refused(reason: PluginSideRefusal.harnessUpdateRequired));
    });

    test("sampleThread throws other errors as request failures", () async {
      final transport = _Transport(responses: [_rpcError(message: "sample timed out")]);

      await expectLater(
        _repository(transport: transport).sampleThread(threadId: "thread-1", expectedTurnId: "turn-1", prompt: "Why?"),
        throwsA(isA<CodexThreadRequestException>().having((error) => error.message, "message", "sample timed out")),
      );
    });

    test("latestTurnId reads one turn, newest first, without items", () async {
      final transport = _Transport(
        responses: [
          {
            "data": [
              {"id": "turn-9", "status": "inProgress", "items": <Object?>[]},
            ],
            "nextCursor": "cursor",
          },
        ],
      );

      final turnId = await _repository(transport: transport).latestTurnId(threadId: "thread-1");

      expect(turnId, "turn-9");
      expect(transport.calls.single.method, "thread/turns/list");
      expect(transport.calls.single.params, {
        "threadId": "thread-1",
        "limit": 1,
        "sortDirection": "desc",
        "itemsView": "notLoaded",
      });
    });

    test("latestTurnId is null for a thread with no turn yet", () async {
      final transport = _Transport(
        responses: [
          {"data": <Object?>[]},
          _rpcError(
            message:
                "thread thread-1 is not materialized yet; thread/turns/list is unavailable before first user message",
          ),
        ],
      );
      final repository = _repository(transport: transport);

      expect(await repository.latestTurnId(threadId: "thread-1"), isNull);
      expect(await repository.latestTurnId(threadId: "thread-1"), isNull);
    });

    test("latestTurnId throws other errors", () async {
      final transport = _Transport(responses: [_rpcError(message: "boom")]);

      await expectLater(
        _repository(transport: transport).latestTurnId(threadId: "thread-1"),
        throwsA(isA<CodexThreadRequestException>()),
      );
    });
  });
}

Matcher _refused({required PluginSideRefusal reason}) =>
    isA<PluginSideRefused>().having((refusal) => refusal.reason, "reason", reason);

CodexRpcException _rpcError({required String message}) =>
    CodexRpcException(method: "thread/sample", code: -32600, message: message, data: null);

CodexThreadRepository _repository({required _Transport transport}) =>
    CodexThreadRepository(appServerApi: CodexAppServerApi(client: transport));

class _Transport({required List<Object?> responses}) implements CodexAppServerTransport {
  final List<Object?> _responses = List.of(responses);
  final calls = <({String method, Object? params, Duration timeout})>[];

  @override
  Stream<CodexServerNotification> get notifications => const Stream.empty();

  @override
  Future<Object?> request({
    required String method,
    required Object? params,
    required Duration timeout,
  }) async {
    calls.add((method: method, params: params, timeout: timeout));
    final response = _responses.removeAt(0);
    if (response is Exception) throw response;
    return response;
  }
}
