import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/external_action_repository.dart";
import "package:sesori_bridge/src/repositories/pending_interaction_support.dart";
import "package:sesori_bridge/src/routing/get_session_external_actions_handler.dart";
import "package:sesori_bridge/src/routing/reply_to_external_action_handler.dart";
import "package:sesori_bridge/src/services/pending_interaction_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fakes/fake_derived_bridge_plugin.dart";
import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  late AppDatabase db;
  late _ExternalPlugin plugin;
  late TestPluginRuntime runtime;
  late ExternalActionRepository repository;
  late PendingInteractionService service;
  const cancel = ReplyToExternalActionRequest(
    requestId: "request",
    sessionId: "child",
    choice: ExternalActionChoice.cancel,
  );
  const accept = ReplyToExternalActionRequest(
    requestId: "request",
    sessionId: "child",
    choice: ExternalActionChoice.accept,
  );

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    plugin = _ExternalPlugin();
    runtime = createTestPluginRuntime(plugins: [plugin]);
    addTearDown(runtime.dispose);
    for (final id in ["root", "child"]) {
      await recordSessionBinding(
        database: db,
        sessionId: id,
        backendSessionId: "$id-native",
        pluginId: plugin.id,
        projectId: "/fixture",
        parentSessionId: id == "child" ? "root" : null,
      );
    }
    plugin.actions = [
      _action(url: "https://fixture.example/authorize?state=private", choices: PluginExternalActionChoice.values),
    ];
    repository = ExternalActionRepository(
      runtime: runtime,
      pendingSupport: PendingInteractionSupport(sessionDao: db.sessionDao),
    );
    final pending = buildTestPendingInteractionService(database: db, plugin: plugin);
    service = pending.service;
    addTearDown(() async {
      service.dispose();
      await pending.dispatcher.dispose();
    });
  });

  test("snapshot maps original owner and display parent; reply cannot use the display session", () async {
    final handler = GetSessionExternalActionsHandler(service: service);
    final snapshot = await handler.handle(
      makeRequest("POST", "/session/external-actions"),
      body: const SessionIdRequest(sessionId: "root"),
    );
    expect(snapshot.data.single.sessionID, "child");
    expect(snapshot.data.single.displaySessionId, "root");
    expect(snapshot.toString(), isNot(contains("https://fixture.example")));
    expect(
      await service.replyToExternalAction(
        request: const ReplyToExternalActionRequest(
          requestId: "request",
          sessionId: "root",
          choice: ExternalActionChoice.accept,
        ),
      ),
      isA<ExternalActionAlreadySettled>(),
    );
    expect(plugin.replies, isEmpty);
    expect(await service.replyToExternalAction(request: accept), isA<ExternalActionReplyAccepted>());
    expect(plugin.replies.single.sessionId, "child-native");
    expect(plugin.replies.single.choice, PluginExternalActionChoice.accept);
    expect(await service.replyToExternalAction(request: accept), isA<ExternalActionAlreadySettled>());
    expect(plugin.replies, hasLength(1));
  });

  for (final url in [
    "http://fixture.example/authorize",
    "/relative",
    "file:///private/fixture",
    "data:text/plain,fixture",
    "javascript:alert(1)",
    "sesori://fixture",
    "https://user:secret@fixture.example/authorize",
    "https:///missing-host",
  ]) {
    test("invalid destination $url cannot be read or accepted; cancellation remains possible", () async {
      plugin.actions = [_action(url: url, choices: PluginExternalActionChoice.values)];
      final failure = throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "status", 422));
      await expectLater(service.getPendingExternalActions(sessionId: "child"), failure);
      await expectLater(service.replyToExternalAction(request: accept), failure);
      expect(plugin.replies, isEmpty);
      expect(await repository.reply(request: cancel), isA<ExternalActionReplyAccepted>());
      expect(plugin.replies.single.choice, PluginExternalActionChoice.cancel);
    });
  }

  test("unknown or undeclared choices never reach the native reply", () async {
    plugin.actions = [
      _action(url: "https://fixture.example", choices: const [PluginExternalActionChoice.cancel]),
    ];
    expect(await repository.reply(request: accept), isA<ExternalActionUnsupportedChoice>());
    expect(
      await repository.reply(
        request: const ReplyToExternalActionRequest(
          requestId: "request",
          sessionId: "child",
          choice: ExternalActionChoice.unknown,
        ),
      ),
      isA<ExternalActionUnsupportedChoice>(),
    );
    expect(plugin.replies, isEmpty);
  });

  test("a stopped plugin is never started to read or answer an old request", () async {
    runtime.stoppedPluginIds.add(plugin.id);
    expect(await repository.getPending(sessionId: "root"), isEmpty);
    expect(await repository.reply(request: cancel), isA<ExternalActionAlreadySettled>());
    expect(plugin.reads, isZero);
    expect(plugin.replies, isEmpty);
  });

  test("deleted owning sessions are hidden and cannot receive consent", () async {
    await db.sessionDao.insertSessionTombstone(backendSessionId: "child-native", pluginId: plugin.id, deletedAt: 1);
    expect(await repository.getPending(sessionId: "root"), isEmpty);
    await expectLater(
      repository.reply(request: accept),
      throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "not found", isTrue)),
    );
    expect(plugin.replies, isEmpty);
  });

  test("archived owning actions are hidden through direct and display-parent reads", () async {
    await db.sessionDao.setArchived(sessionId: "child", archivedAt: 2, updatedAt: 2, projectionUpdatedAt: 2);
    expect(await repository.getPending(sessionId: "child"), isEmpty);
    expect(await repository.getPending(sessionId: "root"), isEmpty);
    expect(plugin.replies, isEmpty);
  });

  test("archived reply returns canonical 409 before native access", () async {
    await db.sessionDao.setArchived(sessionId: "child", archivedAt: 2, updatedAt: 2, projectionUpdatedAt: 2);
    final pending = buildTestPendingInteractionService(database: db, plugin: plugin);
    addTearDown(() async {
      pending.service.dispose();
      await pending.dispatcher.dispose();
    });
    final handler = ReplyToExternalActionHandler(service: pending.service);
    final outcome = await handler.routeInternal(
      request: makeRequest("POST", "/external-action/reply", body: jsonEncode(accept.toJson())),
      targetParams: const (pathParams: <String, String>{}, queryParams: <String, String>{}),
    );
    expect(outcome.response.status, 409);
    final rejection = SessionArchivedRejection.fromJson(jsonDecodeMap(outcome.response.body!));
    expect(rejection.sessionId, "child");
    expect(rejection.reason, SessionArchivedReason.archivedReadOnly);
    expect(plugin.reads, isZero);
    expect(plugin.replies, isEmpty);
  });
}

PluginPendingExternalAction _action({required String url, required List<PluginExternalActionChoice> choices}) =>
    PluginPendingExternalAction(
      id: "request",
      sessionID: "child-native",
      displaySessionId: "root-native",
      title: "Fixture server",
      message: "Continue with the fixture",
      authorizationUrl: url,
      purpose: PluginExternalActionPurpose.authorization,
      choices: choices,
    );

class _ExternalPlugin() extends FakeDerivedBridgePlugin implements SessionExternalActionsPluginApi {
  this : super(id: "fixture", launchDirectory: "/fixture", allSessions: const []);
  List<PluginPendingExternalAction> actions = [];
  final replies = <({String requestId, String sessionId, PluginExternalActionChoice choice})>[];
  int reads = 0;

  @override
  Future<List<PluginPendingExternalAction>> getPendingExternalActions({required String sessionId}) async {
    reads++;
    return actions.where((action) => action.sessionID == sessionId || action.displaySessionId == sessionId).toList();
  }

  @override
  Future<PluginExternalActionReply> replyToExternalAction({
    required String requestId,
    required String sessionId,
    required PluginExternalActionChoice choice,
  }) async {
    if (!actions.any((action) => action.id == requestId && action.sessionID == sessionId)) {
      return PluginExternalActionReply.alreadySettled;
    }
    replies.add((requestId: requestId, sessionId: sessionId, choice: choice));
    actions.removeWhere((action) => action.id == requestId && action.sessionID == sessionId);
    return PluginExternalActionReply.accepted;
  }
}
