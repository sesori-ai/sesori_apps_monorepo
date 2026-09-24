import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/session_continuation_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/models/session_continuation_record.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/session_continuation_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/services/session_continuation_service.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_prompt_service.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";

void main() {
  late AppDatabase db;
  late PluginRuntime runtime;
  late _OutcomeRepository records;
  late _Sessions sessions;
  late SessionOperationDispatcher operations;
  late _Prompts prompts;
  late _Mutations mutations;
  late SessionViewService views;
  late SessionContinuationService service;
  late DateTime now;
  final observed = DateTime.utc(2026, 9, 24, 9);
  final reset = observed.add(const Duration(days: 3));

  setUp(() async {
    db = createTestDatabase();
    runtime = createAlwaysCurrentTestPluginRuntime();
    records = _OutcomeRepository(
      dao: SessionContinuationDao(database: db),
      runtime: runtime,
    );
    sessions = _Sessions();
    operations = SessionOperationDispatcher(sessionRepository: sessions);
    prompts = _Prompts(records: records);
    mutations = _Mutations();
    views = SessionViewService(sessions: sessions, continuations: records, resetBuffer: const Duration(minutes: 2));
    now = observed;
    service = SessionContinuationService(
      continuations: records,
      sessions: sessions,
      views: views,
      operations: operations,
      prompts: prompts,
      mutations: mutations,
      resetBuffer: const Duration(minutes: 2),
      pauseRecheckDelay: const Duration(minutes: 5),
      clock: Clock(() => now),
    );
    await insertTestSession(
      db: db,
      sessionId: "session",
      backendSessionId: "backend",
      pluginId: "plugin",
      projectId: "/fixture",
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
    await operations.dispose();
    await runtime.dispose();
    await db.close();
  });

  Future<void> observe({required DateTime? resetAt}) => service.observeQuota(
    sessionId: "session",
    pluginId: "plugin",
    generation: 1,
    errorMessageId: "quota-error",
    observedAt: observed,
    resetAt: resetAt,
  );
  Future<void> arm() async {
    await observe(resetAt: reset);
    await service.setEnabled(sessionId: "session", enabled: true);
  }

  test("known reset remains visible while off; unsupported enable fails but disable succeeds", () async {
    await observe(resetAt: reset);
    final view = (await views.get(sessionId: "session")).autoContinuation!;
    expect(view.enabled, isFalse);
    expect(
      view.status,
      SessionAutoContinuationStatus.resetKnown(
        resetAt: reset.millisecondsSinceEpoch,
        continueAt: reset.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
      ),
    );
    await service.setEnabled(sessionId: "session", enabled: true);
    sessions.availability = AutoContinuationAvailability.unavailable;
    await expectLater(
      service.setEnabled(sessionId: "session", enabled: true),
      throwsA(isA<SessionAutoContinuationUnavailableException>()),
    );
    expect((await service.setEnabled(sessionId: "session", enabled: false)).autoContinuation!.enabled, isFalse);
  });

  test("uses reset plus buffer, preserves prompt selection, and consumes before one ordinary send", () async {
    await arm();
    now = observed.add(const Duration(minutes: 3));
    await service.runDue();
    expect(sessions.readinessCalls, 0);
    now = reset.add(const Duration(minutes: 2));
    await service.runDue();
    expect(prompts.sent, hasLength(1));
    expect(prompts.sent.single.parts, const [PromptPart.text(text: "Continue.")]);
    expect(prompts.sent.single.model, const PromptModel(providerID: "provider", modelID: "model"));
    expect(prompts.sent.single.variant, const SessionVariant(id: "high"));
    expect(prompts.sent.single.agent, "agent");
    expect(prompts.sent.single.fastMode, isTrue);
    expect(sessions.readinessCalls, 2);
    expect((await records.read(sessionId: "session")).outcome, isA<SessionContinuationSubmitted>());
    await observe(resetAt: reset.add(const Duration(days: 1)));
    await service.runDue();
    expect(prompts.sent, hasLength(1));
    final reloaded = SessionContinuationRepository(
      dao: SessionContinuationDao(database: db),
      runtime: runtime,
    );
    expect((await reloaded.read(sessionId: "session")).outcome, isA<SessionContinuationSubmitted>());
  });

  test("paused deadline survives repository recreation and suppresses premature reads", () async {
    await arm();
    now = reset.add(const Duration(minutes: 2));
    sessions.readiness = SessionContinuationReadiness.awaitingInput;
    await service.runDue();
    expect(sessions.historyCalls, 0);
    final reloaded = SessionContinuationRepository(
      dao: SessionContinuationDao(database: db),
      runtime: runtime,
    );
    final paused = (await reloaded.read(sessionId: "session")).outcome as SessionContinuationPaused;
    expect(paused.recheckAt, now.add(const Duration(minutes: 5)));
    final published = mutations.sessions.length;
    for (var tick = 0; tick < 9; tick++) {
      now = now.add(const Duration(seconds: 30));
      await service.runDue();
    }
    expect(sessions.readinessCalls, 1);
    expect(sessions.historyCalls, 0);
    now = paused.recheckAt;
    await service.runDue();
    expect(sessions.readinessCalls, 2);
    expect(sessions.historyCalls, 0);
    expect(mutations.sessions.length, published);
    expect(await reloaded.readReadyToCheck(sessionId: "session", resetCutoff: now, pausedRecheckCutoff: now), isNull);
  });

  test("native work starting during history pauses without consuming", () async {
    await arm();
    now = reset.add(const Duration(minutes: 2));
    sessions.onHistory = () {
      sessions.readiness = SessionContinuationReadiness.busy;
    };
    await service.runDue();
    expect(prompts.sent, isEmpty);
    expect(
      (await records.read(sessionId: "session")).outcome,
      isA<SessionContinuationPaused>().having((value) => value.reason, "reason", AutoContinuationPauseReason.busy),
    );
  });

  test("new history cancels only this observation and leaves session preference enabled", () async {
    await arm();
    now = reset.add(const Duration(minutes: 2));
    sessions.errorId = "newer-message";
    await service.runDue();
    final record = await records.read(sessionId: "session");
    expect(record.enabled, isTrue);
    expect(record.outcome, isA<SessionContinuationCancelled>());
    await observe(resetAt: reset);
    expect((await records.read(sessionId: "session")).outcome, isA<SessionContinuationCancelled>());
    expect(prompts.sent, isEmpty);
  });

  test("unknown or invalid resets never reach the plugin", () async {
    for (final resetAt in [null, observed, observed.subtract(const Duration(minutes: 1))]) {
      await service.observeQuota(
        sessionId: "session",
        pluginId: "plugin",
        generation: 1,
        errorMessageId: "error-$resetAt",
        observedAt: observed,
        resetAt: resetAt,
      );
      await service.setEnabled(sessionId: "session", enabled: true);
      now = reset.add(const Duration(days: 10));
      await service.runDue();
      expect((await records.read(sessionId: "session")).outcome, isA<SessionContinuationResetUnknown>());
    }
    expect(sessions.readinessCalls, 0);
  });

  test("history failure persists a bounded pause", () async {
    await arm();
    now = reset.add(const Duration(minutes: 2));
    sessions.historyError = StateError("fixture history failed");
    await service.runDue();
    expect(
      (await records.read(sessionId: "session")).outcome,
      isA<SessionContinuationPaused>().having(
        (value) => value.reason,
        "reason",
        AutoContinuationPauseReason.historyUnavailable,
      ),
    );
    expect(prompts.sent, isEmpty);
  });

  test("submission rejection is durable and never retried", () async {
    await arm();
    now = reset.add(const Duration(minutes: 2));
    prompts.error = StateError("fixture rejected");
    await service.runDue();
    await service.runDue();
    expect(prompts.sent, hasLength(1));
    expect((await records.read(sessionId: "session")).outcome, isA<SessionContinuationSubmissionFailed>());
  });

  test("post-acceptance write failure leaves unconfirmed consumption and never resends", () async {
    await arm();
    now = reset.add(const Duration(minutes: 2));
    records.failSubmitted = true;
    await service.runDue();
    await service.runDue();
    expect(prompts.sent, hasLength(1));
    expect((await records.read(sessionId: "session")).outcome, isA<SessionContinuationConsumed>());
    expect(
      (await views.get(sessionId: "session")).autoContinuation!.status,
      const SessionAutoContinuationStatus.attemptUnconfirmed(),
    );
  });

  test("generation rejection before admission does not persist an observation", () async {
    await expectLater(
      service.observeQuota(
        sessionId: "session",
        pluginId: "plugin",
        generation: 2,
        errorMessageId: "quota-error",
        observedAt: observed,
        resetAt: reset,
      ),
      throwsA(isA<PluginOperationException>()),
    );
    expect((await records.read(sessionId: "session")).outcome, isA<SessionContinuationNone>());
  });

  test("queued observation waits for the existing session lane", () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final manual = operations.dispatch(
      sessionId: "session",
      operation: SessionOperation.sendPrompt,
      body: () async {
        started.complete();
        await release.future;
      },
    );
    await started.future;
    final observation = observe(resetAt: reset);
    expect((await records.read(sessionId: "session")).outcome, isA<SessionContinuationNone>());
    release.complete();
    await manual;
    await observation;
    expect((await records.read(sessionId: "session")).outcome, isA<SessionContinuationResetKnown>());
  });

  test("deleting the named session cascades its continuation record", () async {
    await arm();
    await db.customStatement("DELETE FROM sessions_table WHERE session_id = ?", ["session"]);
    expect(await SessionContinuationDao(database: db).read(sessionId: "session"), isNull);
  });
}

class _OutcomeRepository({required SessionContinuationDao dao, required PluginRuntime runtime})
    extends SessionContinuationRepository {
  this : super(dao: dao, runtime: runtime);
  bool failSubmitted = false;
  @override
  Future<void> writeOutcomeAlreadyReserved({
    required SessionContinuationRecord record,
    required SessionContinuationOutcome outcome,
  }) {
    if (failSubmitted && outcome is SessionContinuationSubmitted) throw StateError("fixture outcome write failed");
    return super.writeOutcomeAlreadyReserved(record: record, outcome: outcome);
  }
}

class _Sessions() implements SessionRepository {
  AutoContinuationAvailability availability = AutoContinuationAvailability.conditional;
  SessionContinuationReadiness readiness = SessionContinuationReadiness.idle;
  int readinessCalls = 0;
  int historyCalls = 0;
  String errorId = "quota-error";
  Object? historyError;
  void Function()? onHistory;
  @override
  AutoContinuationAvailability quotaReportingAvailability({required String pluginId}) => availability;
  @override
  Future<SessionContinuationReadiness> getQuotaContinuationReadiness({required String sessionId}) async {
    readinessCalls++;
    return readiness;
  }

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async => (pluginId: "plugin", rootSessionId: sessionId);
  @override
  Future<Session?> getCatalogSession({required String sessionId}) async => Session(
    id: sessionId,
    pluginId: "plugin",
    projectID: "/fixture",
    directory: "/fixture",
    parentID: null,
    title: null,
    branchName: null,
    time: null,
    pullRequest: null,
    promptDefaults: null,
    hasWorktree: false,
    unseen: false,
    lastUserActivityAt: null,
    autoContinuation: null,
  );
  @override
  Future<SessionMessagesSnapshot> getSessionMessages({required String sessionId}) async {
    historyCalls++;
    onHistory?.call();
    if (historyError case final error?) throw error;
    return (
      messages: [
        MessageWithParts(
          info: Message.error(
            id: errorId,
            sessionID: sessionId,
            agent: null,
            modelID: null,
            providerID: null,
            errorName: "quota",
            errorMessage: "fixture limit",
            time: null,
          ),
          parts: const [],
        ),
      ],
      promptDefaults: const SessionPromptDefaults(
        agent: "agent",
        model: AgentModel(providerID: "provider", modelID: "model", variant: "high"),
        fastMode: true,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Sent = ({List<PromptPart> parts, PromptModel? model, SessionVariant? variant, String? agent, bool fastMode});

class _Prompts({required final SessionContinuationRepository records}) implements SessionPromptService {
  final List<_Sent> sent = [];
  Object? error;
  @override
  Future<void> sendPromptAlreadyReserved({
    required String sessionId,
    required String promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
  }) async {
    expect(
      (await records.read(sessionId: sessionId)).outcome,
      isA<SessionContinuationConsumed>().having((value) => value.promptId, "promptId", promptId),
    );
    sent.add((parts: parts, model: model, variant: variant, agent: agent, fastMode: fastMode));
    if (error case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Mutations() implements SessionMutationDispatcher {
  final List<Session> sessions = [];
  @override
  void continuationUpdated({required Session session}) => sessions.add(session);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
