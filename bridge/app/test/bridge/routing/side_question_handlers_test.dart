import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/api/database/daos/side_chat_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/repositories/side_chat_repository.dart";
import "package:sesori_bridge/src/routing/ask_side_question_handler.dart";
import "package:sesori_bridge/src/routing/get_side_chats_handler.dart";
import "package:sesori_bridge/src/services/archived_session_validator.dart";
import "package:sesori_bridge/src/services/side_question_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  late AppDatabase db;
  late _SideQuestionPlugin plugin;
  late TestPluginRuntime runtime;
  late AskSideQuestionHandler askHandler;
  late GetSideChatsHandler listHandler;

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    plugin = _SideQuestionPlugin();
    addTearDown(plugin.close);
    runtime = createTestPluginRuntime(plugins: [plugin])..sideQuestionPluginIds.add(plugin.id);
    await recordSessionBinding(
      database: db,
      sessionId: "s-1",
      backendSessionId: "backend-s-1",
      pluginId: plugin.id,
      projectId: "/repo",
      parentSessionId: null,
    );
    final sessionRepository = singlePluginSessionRepository(
      plugin: plugin,
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
      runtime: runtime,
    );
    final sideChatRepository = SideChatRepository(dao: SideChatDao(database: db));
    askHandler = AskSideQuestionHandler(
      sideQuestionService: SideQuestionService(
        archivedSessionValidator: ArchivedSessionValidator(sessionRepository: sessionRepository),
        sessionRepository: sessionRepository,
        sideChatRepository: sideChatRepository,
      ),
    );
    listHandler = GetSideChatsHandler(sideChatRepository: sideChatRepository);
  });

  Future<RelayResponse> ask({required String sessionId, required String? sideChatId, required String question}) {
    final body = AskSideQuestionRequest(sessionId: sessionId, sideChatId: sideChatId, question: question);
    return askHandler.routeForTest(makeRequest("POST", "/session/side-question", body: jsonEncode(body.toJson())));
  }

  AskSideQuestionResponse decodeAsk(RelayResponse response) {
    expect(response.status, 200);
    return AskSideQuestionResponse.fromJson(jsonDecodeMap(response.body ?? ""));
  }

  Future<SideChatListResponse> listSideChats() async {
    final response = await listHandler.routeForTest(
      makeRequest("POST", "/session/side-chats", body: jsonEncode(const SessionIdRequest(sessionId: "s-1").toJson())),
    );
    expect(response.status, 200);
    return SideChatListResponse.fromJson(jsonDecodeMap(response.body ?? ""));
  }

  test("handles POST /session/side-question and POST /session/side-chats", () {
    expect(askHandler.canHandle(makeRequest("POST", "/session/side-question")), isTrue);
    expect(listHandler.canHandle(makeRequest("POST", "/session/side-chats")), isTrue);
  });

  test("an answer is stored, and a follow-up sends the chat's history to the backend session", () async {
    plugin.answer = const PluginSideAnswered(text: "first answer", notice: "fallback model");
    final first = decodeAsk(await ask(sessionId: "s-1", sideChatId: null, question: "first?"));
    final AskSideQuestionAnswered(:sideChatId, :exchange) = switch (first) {
      final AskSideQuestionAnswered answered => answered,
      _ => fail("expected an answer, got $first"),
    };
    expect(exchange.question, "first?");
    expect(exchange.answer, "first answer");
    expect(exchange.answerNotice, "fallback model");

    plugin.answer = const PluginSideAnswered(text: "second answer", notice: null);
    final second = decodeAsk(await ask(sessionId: "s-1", sideChatId: sideChatId, question: "second?"));

    expect(second, isA<AskSideQuestionAnswered>().having((r) => r.sideChatId, "sideChatId", sideChatId));
    expect(plugin.asks.map((ask) => ask.sessionId), ["backend-s-1", "backend-s-1"]);
    expect(plugin.asks.first.history, isEmpty);
    expect(plugin.asks.last.question, "second?");
    expect(plugin.asks.last.history.map((h) => (h.question, h.answer)), [("first?", "first answer")]);

    final listed = await listSideChats();
    expect(listed.sideChats.single.id, sideChatId);
    expect(listed.sideChats.single.exchanges.map((e) => e.answer), ["first answer", "second answer"]);
  });

  test("a refusal returns its reason and stores nothing", () async {
    plugin.answer = const PluginSideRefused(reason: PluginSideRefusal.noTurnYet);

    final response = decodeAsk(await ask(sessionId: "s-1", sideChatId: null, question: "q"));

    expect(response, isA<AskSideQuestionRefused>().having((r) => r.reason, "reason", SideQuestionRefusal.noTurnYet));
    expect((await listSideChats()).sideChats, isEmpty);
  });

  test("a harness that does not declare side questions is refused without starting its plugin", () async {
    runtime.sideQuestionPluginIds.clear();
    final started = runtime.useStarted = Completer<void>();

    final response = decodeAsk(await ask(sessionId: "s-1", sideChatId: null, question: "q"));

    expect(
      response,
      isA<AskSideQuestionRefused>().having((r) => r.reason, "reason", SideQuestionRefusal.harnessUnsupported),
    );
    expect(started.isCompleted, isFalse);
    expect(plugin.asks, isEmpty);
  });

  test("a harness that declares side questions but lacks the API fails loudly", () async {
    final plainPlugin = FakeBridgePlugin();
    addTearDown(plainPlugin.close);
    final plainRuntime = createTestPluginRuntime(plugins: [plainPlugin])..sideQuestionPluginIds.add(plainPlugin.id);
    final repository = singlePluginSessionRepository(
      plugin: plainPlugin,
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
      runtime: plainRuntime,
    );
    final handler = AskSideQuestionHandler(
      sideQuestionService: SideQuestionService(
        archivedSessionValidator: ArchivedSessionValidator(sessionRepository: repository),
        sessionRepository: repository,
        sideChatRepository: SideChatRepository(dao: SideChatDao(database: db)),
      ),
    );
    const body = AskSideQuestionRequest(sessionId: "s-1", sideChatId: null, question: "q");

    final response = await handler.routeForTest(
      makeRequest("POST", "/session/side-question", body: jsonEncode(body.toJson())),
    );

    expect(response.status, 500);
  });

  test("an archived session answers with the archived rejection", () async {
    await db.sessionDao.setArchived(sessionId: "s-1", archivedAt: 10, updatedAt: 10, projectionUpdatedAt: 10);

    final response = await ask(sessionId: "s-1", sideChatId: null, question: "q");

    expect(response.status, 409);
    expect(
      SessionArchivedRejection.fromJson(jsonDecodeMap(response.body ?? "")).reason,
      SessionArchivedReason.archivedReadOnly,
    );
    expect(plugin.asks, isEmpty);
  });

  test("a sub-agent session is a bad request", () async {
    await recordSessionBinding(
      database: db,
      sessionId: "child-1",
      backendSessionId: "backend-child-1",
      pluginId: plugin.id,
      projectId: "/repo",
      parentSessionId: "s-1",
    );

    final response = await ask(sessionId: "child-1", sideChatId: null, question: "q");

    expect(response.status, 400);
    expect(plugin.asks, isEmpty);
  });

  test("an unknown session is not found", () async {
    final response = await ask(sessionId: "missing", sideChatId: null, question: "q");

    expect(response.status, 404);
  });

  test("rejects unparseable and empty bodies", () async {
    for (final body in [
      "not json",
      jsonEncode({"sessionId": "s-1"}),
      jsonEncode(const AskSideQuestionRequest(sessionId: "", sideChatId: null, question: "q").toJson()),
      jsonEncode(const AskSideQuestionRequest(sessionId: "s-1", sideChatId: null, question: "  ").toJson()),
    ]) {
      final response = await askHandler.routeForTest(makeRequest("POST", "/session/side-question", body: body));
      expect(response.status, 400, reason: body);
    }
    final listResponse = await listHandler.routeForTest(makeRequest("POST", "/session/side-chats", body: "{}"));
    expect(listResponse.status, 400);
    expect(plugin.asks, isEmpty);
  });
}

class _SideQuestionPlugin() extends FakeBridgePlugin implements SideQuestionPluginApi {
  PluginSideAnswer answer = const PluginSideAnswered(text: "answer", notice: null);
  final List<({String sessionId, String question, List<PluginSideExchange> history})> asks = [];

  @override
  Future<PluginSideAnswer> askSideQuestion({
    required String sessionId,
    required String question,
    required List<PluginSideExchange> history,
  }) async {
    asks.add((sessionId: sessionId, question: question, history: history));
    return answer;
  }
}
