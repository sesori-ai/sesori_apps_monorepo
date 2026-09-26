import "dart:io";

import "package:drift/native.dart";
import "package:sesori_bridge/src/api/database/daos/session_continuation_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/models/session_continuation_record.dart";
import "package:sesori_bridge/src/repositories/session_continuation_repository.dart";
import "package:sesori_bridge/src/runtime/plugin_runtime.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";

void main() {
  late Directory directory;
  late File file;
  late AppDatabase db;
  late PluginRuntime runtime;
  late SessionContinuationRepository repository;
  final observedAt = DateTime.utc(2026, 9, 24);
  final resetAt = observedAt.add(const Duration(days: 3));

  void openDatabase() {
    db = AppDatabase(NativeDatabase(file));
    repository = SessionContinuationRepository(
      dao: SessionContinuationDao(database: db),
      runtime: runtime,
    );
  }

  setUp(() async {
    directory = Directory.systemTemp.createTempSync("continuation-storage-");
    file = File("${directory.path}/bridge.sqlite");
    runtime = createAlwaysCurrentTestPluginRuntime();
    openDatabase();
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
    await db.close();
    await runtime.dispose();
    directory.deleteSync(recursive: true);
  });

  Future<bool> observe({required int generation, required String errorId}) =>
      repository.recordObservationForCurrentGenerationAlreadyReserved(
        sessionId: "session",
        pluginId: "plugin",
        generation: generation,
        errorMessageId: errorId,
        observedAt: observedAt,
        resetAt: resetAt,
      );

  test("preference is independent of observations and pause deadlines survive database reopen", () async {
    expect((await repository.read(sessionId: "session")).enabled, isFalse);
    await observe(generation: 1, errorId: "error");
    expect(await repository.readEnabledReadyToCheck(resetCutoff: resetAt, pausedRecheckCutoff: resetAt), isEmpty);
    await repository.setEnabledAlreadyReserved(sessionId: "session", enabled: true);
    expect(
      await repository.readReadyToCheck(sessionId: "session", resetCutoff: observedAt, pausedRecheckCutoff: resetAt),
      isNull,
    );
    final record = await repository.readReadyToCheck(
      sessionId: "session",
      resetCutoff: resetAt,
      pausedRecheckCutoff: resetAt,
    );
    final recheckAt = resetAt.add(const Duration(minutes: 7));
    final paused = SessionContinuationOutcome.paused(
      errorMessageId: "error",
      observedAt: observedAt,
      resetAt: resetAt,
      reason: AutoContinuationPauseReason.busy,
      recheckAt: recheckAt,
    );
    await repository.writeOutcomeAlreadyReserved(record: record!, outcome: paused);
    await db.close();
    openDatabase();
    expect((await repository.read(sessionId: "session")).outcome, paused);
    expect(await repository.readEnabledReadyToCheck(resetCutoff: recheckAt, pausedRecheckCutoff: resetAt), isEmpty);
    expect(
      await repository.readReadyToCheck(sessionId: "session", resetCutoff: recheckAt, pausedRecheckCutoff: resetAt),
      isNull,
    );
    final due = await repository.readEnabledReadyToCheck(resetCutoff: recheckAt, pausedRecheckCutoff: recheckAt);
    expect(due.single.enabled, isTrue);
    expect(due.single.outcome, paused);
  });

  test("cancelled and consumed observations cannot rearm after a restart; later errors retain opt-in", () async {
    await repository.setEnabledAlreadyReserved(sessionId: "session", enabled: true);
    await observe(generation: 1, errorId: "first-error");
    expect(await repository.cancelCurrentObservationAlreadyReserved(sessionId: "session"), isTrue);
    await db.close();
    openDatabase();
    expect(await observe(generation: 1, errorId: "first-error"), isFalse);
    expect((await repository.read(sessionId: "session")).outcome, isA<SessionContinuationCancelled>());
    expect(await observe(generation: 1, errorId: "second-error"), isTrue);
    final record = await repository.read(sessionId: "session");
    expect(record.enabled, isTrue);
    final consumed = SessionContinuationOutcome.consumed(
      errorMessageId: "second-error",
      promptId: "prompt",
      attemptedAt: resetAt,
    );
    await repository.writeOutcomeAlreadyReserved(record: record, outcome: consumed);
    await db.close();
    openDatabase();
    expect(await observe(generation: 1, errorId: "second-error"), isFalse);
    expect(await repository.cancelCurrentObservationAlreadyReserved(sessionId: "session"), isFalse);
    expect((await repository.read(sessionId: "session")).outcome, consumed);
    expect(await repository.readEnabledReadyToCheck(resetCutoff: resetAt, pausedRecheckCutoff: resetAt), isEmpty);
    await repository.setEnabledAlreadyReserved(sessionId: "session", enabled: false);
    expect((await repository.read(sessionId: "session")).outcome, consumed);
  });

  test("generation fence rejects stale observations and cancellation before persistence", () async {
    await observe(generation: 1, errorId: "current");
    await expectLater(observe(generation: 2, errorId: "stale"), throwsA(isA<PluginOperationException>()));
    await expectLater(
      repository.cancelForCurrentGenerationAlreadyReserved(sessionId: "session", pluginId: "plugin", generation: 2),
      throwsA(isA<PluginOperationException>()),
    );
    expect((await repository.read(sessionId: "session")).outcome.observationId, "current");
    expect(
      await repository.cancelForCurrentGenerationAlreadyReserved(
        sessionId: "session",
        pluginId: "plugin",
        generation: 1,
      ),
      isTrue,
    );
  });

  test("malformed persisted JSON fails explicitly at the object boundary", () async {
    for (final json in ["[]", "null", "{"]) {
      await SessionContinuationDao(database: db).upsert(
        row: SessionContinuationDto(sessionId: "session", enabled: true, outcomeJson: json),
      );
      await expectLater(repository.read(sessionId: "session"), throwsFormatException);
    }
  });

  test("all persisted outcomes round-trip and session deletion cascades storage", () async {
    final outcomes = [
      const SessionContinuationOutcome.none(),
      SessionContinuationOutcome.resetUnknown(errorMessageId: "unknown", observedAt: observedAt),
      SessionContinuationOutcome.resetKnown(errorMessageId: "known", observedAt: observedAt, resetAt: resetAt),
      SessionContinuationOutcome.submitted(errorMessageId: "submitted", promptId: "prompt", acceptedAt: resetAt),
      const SessionContinuationOutcome.submissionFailed(
        errorMessageId: "failed",
        reason: AutoContinuationFailureReason.submissionRejected,
      ),
    ];
    for (final outcome in outcomes) {
      await repository.writeOutcomeAlreadyReserved(
        record: await repository.read(sessionId: "session"),
        outcome: outcome,
      );
      expect((await repository.readMany(sessionIds: {"session", "missing"}))["session"]!.outcome, outcome);
    }
    await db.customStatement("DELETE FROM sessions_table WHERE session_id = ?", ["session"]);
    expect(await SessionContinuationDao(database: db).read(sessionId: "session"), isNull);
  });
}
