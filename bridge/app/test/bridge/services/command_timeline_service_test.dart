import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/models/accepted_command_invocation.dart";
import "package:sesori_bridge/src/bridge/repositories/models/command_timeline.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/command_dispatch_outcome.dart";
import "package:sesori_bridge/src/bridge/services/command_timeline_mutation.dart";
import "package:sesori_bridge/src/bridge/services/command_timeline_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  late AppDatabase db;
  late _HistoryPlugin plugin;
  late SessionRepository sessionRepository;
  late TestCommandStack stack;
  late CommandTimelineService timeline;

  setUp(() async {
    db = createTestDatabase();
    plugin = _HistoryPlugin();
    sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      pullRequestDao: db.pullRequestDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    stack = TestCommandStack(db);
    timeline = stack.timelineService(sessionRepository: sessionRepository);
    await _insertSession(
      repository: sessionRepository,
      sessionId: "session",
      backendSessionId: "backend-session",
    );
  });

  tearDown(() => db.close());

  test("history keeps fallback separate and points display at stable result text", () async {
    const accepted = AcceptedCommandInvocation(
      invocationId: "invocation",
      sessionId: "session",
      pluginId: "plugin",
      name: "review",
      arguments: "carefully",
      acceptedAt: 20,
      backendMessageId: null,
    );
    await stack.repository.save(invocation: accepted);
    plugin.messages = const [
      PluginMessageWithParts(
        info: PluginMessage.command(
          id: "backend-command",
          sessionID: "backend-session",
          name: "backend-name",
          arguments: "backend-arguments",
          origin: PluginCommandOrigin.manual,
          invocationId: "invocation",
          time: PluginMessageTime(created: 21, completed: 30),
        ),
        parts: [
          PluginMessagePart(
            id: "result",
            sessionID: "backend-session",
            messageID: "backend-command",
            type: PluginMessagePartType.text,
            text: "Review complete",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ],
      ),
    ];

    final card = (await timeline.getSessionMessages(sessionId: "session")).single;
    final info = (card.info as MessageUser).command!;

    expect(info.displayPartID, "command-invocation:invocation:display");
    expect(card.parts.map((part) => part.id), [
      "command-invocation:invocation:fallback",
      "command-invocation:invocation:display",
    ]);
    expect(card.parts.map((part) => part.text), ["/review carefully", "Review complete"]);
    expect(
      (await stack.repository.getForSession(pluginId: "plugin", sessionId: "session")).single.backendMessageId,
      "backend-command",
    );
  });

  test("automatic plugin commands remain standalone cards", () async {
    plugin.messages = const [
      PluginMessageWithParts(
        info: PluginMessage.command(
          id: "automatic-command",
          sessionID: "backend-session",
          name: "compact",
          arguments: null,
          origin: PluginCommandOrigin.automatic,
          invocationId: null,
          time: PluginMessageTime(created: 10, completed: null),
        ),
        parts: [],
      ),
    ];

    final card = (await timeline.getSessionMessages(sessionId: "session")).single;

    expect(card.info.id, "command-backend:automatic-command");
    expect((card.info as MessageUser).command?.origin, CommandOrigin.automatic);
    expect(card.parts.first.text, "/compact");
    expect(card.parts.last.text, "");
  });

  test("plugin candidate before acceptance is held and released as one canonical card", () async {
    final before = await timeline.canonicalizePluginCandidate(
      candidate: _commandCandidate(invocationId: "invocation"),
    );
    expect(before.handled, isTrue);
    expect(before.mutations, isEmpty);

    final accepted = await timeline.canonicalizeDispatchOutcome(
      outcome: AcceptedCommandDispatchOutcome(
        invocation: const AcceptedCommandInvocation(
          invocationId: "invocation",
          sessionId: "session",
          pluginId: "plugin",
          name: "review",
          arguments: null,
          acceptedAt: 20,
          backendMessageId: null,
        ),
      ),
    );
    final envelopeMutations = accepted.mutations.whereType<CommandTimelineEnvelopeUpdated>().toList();

    expect(envelopeMutations, hasLength(1));
    expect(envelopeMutations.single.info.id, "command-invocation:invocation");
    expect(accepted.mutations.clear, throwsUnsupportedError);
  });

  test("plugin candidate before rejection and all late candidates emit no card", () async {
    expect(
      (await timeline.canonicalizePluginCandidate(
        candidate: _commandCandidate(invocationId: "rejected"),
      )).mutations,
      isEmpty,
    );
    final rejected = await timeline.canonicalizeDispatchOutcome(
      outcome: RejectedCommandDispatchOutcome(
        pluginId: "plugin",
        sessionId: "session",
        invocationId: "rejected",
        error: StateError("rejected"),
        stackTrace: StackTrace.current,
      ),
    );
    final late = await timeline.canonicalizePluginCandidate(
      candidate: _commandCandidate(invocationId: "rejected"),
    );

    expect(rejected.mutations, isEmpty);
    expect(late.handled, isTrue);
    expect(late.mutations, isEmpty);
  });

  test("the same backend message id stays isolated across sessions", () async {
    await _insertSession(
      repository: sessionRepository,
      sessionId: "session-2",
      backendSessionId: "backend-session-2",
    );
    for (final invocation in const [
      AcceptedCommandInvocation(
        invocationId: "one",
        sessionId: "session",
        pluginId: "plugin",
        name: "review",
        arguments: null,
        acceptedAt: 1,
        backendMessageId: "same-backend-id",
      ),
      AcceptedCommandInvocation(
        invocationId: "two",
        sessionId: "session-2",
        pluginId: "plugin",
        name: "review",
        arguments: null,
        acceptedAt: 2,
        backendMessageId: "same-backend-id",
      ),
    ]) {
      await timeline.canonicalizeDispatchOutcome(outcome: AcceptedCommandDispatchOutcome(invocation: invocation));
    }

    final first = await timeline.canonicalizePluginCandidate(
      candidate: _resultCandidate(sessionId: "session", text: "one"),
    );
    final second = await timeline.canonicalizePluginCandidate(
      candidate: _resultCandidate(sessionId: "session-2", text: "two"),
    );
    final firstPart = first.mutations.whereType<CommandTimelinePartUpdated>().single.part;
    final secondPart = second.mutations.whereType<CommandTimelinePartUpdated>().single.part;

    expect(firstPart.messageID, "command-invocation:one");
    expect(secondPart.messageID, "command-invocation:two");
  });

  test("mixed null timestamps preserve source order", () async {
    plugin.messages = const [
      PluginMessageWithParts(
        info: PluginMessage.user(id: "source-first", sessionID: "backend-session", agent: null, time: null),
        parts: [],
      ),
      PluginMessageWithParts(
        info: PluginMessage.user(
          id: "timed-second",
          sessionID: "backend-session",
          agent: null,
          time: PluginMessageTime(created: 1, completed: null),
        ),
        parts: [],
      ),
    ];

    final messages = await timeline.getSessionMessages(sessionId: "session");

    expect(messages.map((message) => message.info.id), ["source-first", "timed-second"]);
  });

  test("a repeated plugin envelope does not clear existing result text", () async {
    final first = await timeline.canonicalizePluginCandidate(
      candidate: _commandCandidate(
        invocationId: null,
        resultParts: [_textPart(messageId: "backend-command", text: "complete")],
      ),
    );
    final repeated = await timeline.canonicalizePluginCandidate(
      candidate: _commandCandidate(invocationId: null),
    );
    final firstDisplay = first.mutations
        .whereType<CommandTimelinePartUpdated>()
        .map((mutation) => mutation.part)
        .singleWhere((part) => part.id.endsWith(":display"));
    final repeatedDisplay = repeated.mutations
        .whereType<CommandTimelinePartUpdated>()
        .map((mutation) => mutation.part)
        .singleWhere((part) => part.id.endsWith(":display"));

    expect(firstDisplay.text, "complete");
    expect(repeatedDisplay.text, "complete");
  });
}

CommandMessageTimelineCandidate _commandCandidate({
  required String? invocationId,
  List<MessagePart> resultParts = const [],
}) {
  return CommandMessageTimelineCandidate(
    pluginId: "plugin",
    sessionId: "session",
    backendMessageId: "backend-command",
    invocationId: invocationId,
    name: "review",
    arguments: null,
    origin: CommandOrigin.manual,
    time: const MessageTime(created: 10, completed: null),
    resultParts: resultParts,
  );
}

CommandResultPartTimelineCandidate _resultCandidate({required String sessionId, required String text}) {
  return CommandResultPartTimelineCandidate(
    pluginId: "plugin",
    sessionId: sessionId,
    backendMessageId: "same-backend-id",
    backendPartId: "result",
    part: _textPart(messageId: "same-backend-id", text: text, sessionId: sessionId),
  );
}

MessagePart _textPart({
  required String messageId,
  required String text,
  String sessionId = "session",
}) {
  return MessagePart(
    id: "result",
    sessionID: sessionId,
    messageID: messageId,
    type: MessagePartType.text,
    text: text,
    tool: null,
    state: null,
    prompt: null,
    description: null,
    agent: null,
    agentName: null,
    attempt: null,
    retryError: null,
  );
}

Future<void> _insertSession({
  required SessionRepository repository,
  required String sessionId,
  required String backendSessionId,
}) {
  return repository.insertStoredSession(
    sessionId: sessionId,
    backendSessionId: backendSessionId,
    pluginId: "plugin",
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
}

class _HistoryPlugin implements NativeProjectsPluginApi {
  List<PluginMessageWithParts> messages = const [];

  @override
  String get id => "plugin";

  @override
  Stream<BridgeSseEvent> get events => const Stream.empty();

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId, {
    required List<PluginCommandInvocationContext> acceptedCommands,
  }) async => messages;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
