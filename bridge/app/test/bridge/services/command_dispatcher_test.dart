import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/command_dispatch_outcome.dart";
import "package:sesori_bridge/src/bridge/services/command_dispatcher.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  late AppDatabase db;
  late _CommandPlugin plugin;
  late TestCommandStack commandStack;
  late SessionRepository sessionRepository;
  late CommandDispatcher dispatcher;

  setUp(() async {
    db = createTestDatabase();
    plugin = _CommandPlugin();
    commandStack = TestCommandStack(db);
    sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      pullRequestDao: db.pullRequestDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    dispatcher = commandStack.dispatcher(
      plugin: plugin,
      sessionRepository: sessionRepository,
      clock: Clock.fixed(DateTime.fromMillisecondsSinceEpoch(1234)),
    );
    await sessionRepository.insertStoredSession(
      sessionId: "session",
      backendSessionId: "backend-session",
      pluginId: plugin.id,
      projectId: "project",
      isDedicated: false,
      createdAt: 1,
      worktreePath: null,
      branchName: null,
      baseBranch: null,
      baseCommit: null,
      agent: null,
      agentModel: null,
    );
  });

  tearDown(() async {
    await dispatcher.dispose();
    await db.close();
  });

  test("rejection emits a rejected outcome and leaves no durable invocation", () async {
    plugin.dispatchError = StateError("rejected");
    final emitted = <CommandDispatchOutcome>[];
    final subscription = dispatcher.outcomes.listen(emitted.add);
    addTearDown(subscription.cancel);

    await expectLater(
      dispatcher.dispatch(
        sessionId: "session",
        name: "review",
        arguments: null,
        variant: null,
        agent: null,
        model: null,
      ),
      throwsA(isA<StateError>()),
    );

    expect(emitted, [isA<RejectedCommandDispatchOutcome>()]);
    expect(
      await commandStack.repository.getForSession(pluginId: plugin.id, sessionId: "session"),
      isEmpty,
    );
  });

  test("accepted dispatch persists before emitting its accepted outcome", () async {
    plugin.backendMessageId = "backend-message";
    final emitted = <CommandDispatchOutcome>[];
    final subscription = dispatcher.outcomes.listen(emitted.add);
    addTearDown(subscription.cancel);

    final outcome = await dispatcher.dispatch(
      sessionId: "session",
      name: "review",
      arguments: null,
      variant: const SessionVariant(id: "high"),
      agent: "planner",
      model: const PromptModel(providerID: "provider", modelID: "model"),
    );
    final accepted = outcome;

    expect(plugin.invocationId, accepted.invocation.invocationId);
    expect(plugin.sessionId, "backend-session");
    expect(plugin.arguments, "");
    expect(accepted.invocation.arguments, isNull);
    expect(accepted.invocation.acceptedAt, 1234);
    expect(accepted.invocation.backendMessageId, "backend-message");
    expect(emitted, [same(outcome)]);
    expect(
      await commandStack.repository.getForSession(pluginId: plugin.id, sessionId: "session"),
      [accepted.invocation],
    );
  });
}

class _CommandPlugin implements NativeProjectsPluginApi {
  Object? dispatchError;
  String? backendMessageId;
  String? invocationId;
  String? sessionId;
  String? arguments;

  @override
  String get id => "plugin";

  @override
  Stream<BridgeSseEvent> get events => const Stream.empty();

  @override
  Future<PluginCommandDispatch> sendCommand({
    required String sessionId,
    required String invocationId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    final error = dispatchError;
    if (error != null) throw error;
    this.sessionId = sessionId;
    this.invocationId = invocationId;
    this.arguments = arguments;
    return PluginCommandDispatch(backendMessageId: backendMessageId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
