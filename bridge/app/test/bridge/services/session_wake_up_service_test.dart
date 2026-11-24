import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/session_wake_up_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/models/sesori_mcp_caller.dart";
import "package:sesori_bridge/src/repositories/models/session_notice.dart";
import "package:sesori_bridge/src/repositories/models/session_wake_up.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/repositories/session_wake_up_repository.dart";
import "package:sesori_bridge/src/services/scheduled_task_occurrence_calculator.dart";
import "package:sesori_bridge/src/services/session_notice_service.dart";
import "package:sesori_bridge/src/services/session_wake_up_description_builder.dart";
import "package:sesori_bridge/src/services/session_wake_up_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:timezone/data/latest_all.dart" as tz_data;

import "../../helpers/fakes/fake_bridge_plugin.dart";
import "../../helpers/test_database.dart";

const _caller = SesoriMcpCaller(sessionId: "s1");

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late SessionWakeUpRepository wakeUps;
  late _Notices notices;
  late DateTime now;

  setUpAll(tz_data.initializeTimeZones);

  SessionWakeUpService buildService() => SessionWakeUpService(
    wakeUps: wakeUps,
    sessions: sessions,
    calculator: const ScheduledTaskOccurrenceCalculator(),
    notices: notices,
    descriptions: const SessionWakeUpDescriptionBuilder(),
    localTimeZone: () => "Europe/Bucharest",
    clock: Clock(() => now),
  );

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    sessions = singlePluginSessionRepository(
      plugin: FakeBridgePlugin(),
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    wakeUps = SessionWakeUpRepository(dao: SessionWakeUpDao(database: db));
    notices = _Notices();
    now = DateTime.utc(2026, 11, 15, 10);
    await insertTestSession(
      db: db,
      sessionId: "s1",
      backendSessionId: "backend-s1",
      pluginId: "fake",
      projectId: "/repo",
      isDedicated: false,
      createdAt: 1,
      worktreePath: null,
      baseBranch: null,
      baseCommit: null,
      agent: null,
      agentModel: null,
    );
  });

  Future<StoredSessionWakeUp> schedule({
    required SessionWakeUpService service,
    required WakeUpRequestedTime when,
  }) async {
    final result = await service.schedule(caller: _caller, label: "Check", prompt: "Look at CI", when: when, timeZone: null);
    return switch (result) {
      WakeUpScheduled(:final wakeUp) => wakeUp,
      WakeUpRefused(:final reason) => fail("refused: $reason"),
    };
  }

  test("a due one-shot is sent after the turn and removed by its claim", () async {
    final service = buildService();
    final wakeUp = await schedule(service: service, when: const WakeUpInMinutes(minutes: 5));

    await service.runDue();
    await pumpEventQueue();
    expect(notices.sent, isEmpty);

    now = now.add(const Duration(minutes: 5));
    await service.runDue();
    await pumpEventQueue();

    final sent = notices.sent.single;
    expect(sent.sessionId, "s1");
    expect(sent.timing, SessionNoticeTiming.afterTurn);
    expect(sent.notice.summary, "Wake-up: Check");
    expect(sent.notice.guidance, contains("It does not repeat."));
    expect(sent.notice.guidance, endsWith("Your prompt:\nLook at CI"));
    expect(sent.notice.guidance, isNot(contains("late")));
    expect(await wakeUps.exists(id: wakeUp.id), isFalse);
  });

  test("a repeating wake-up moves past the times it missed and fires once", () async {
    final service = buildService();
    final wakeUp = await schedule(service: service, when: const WakeUpEveryMinutes(minutes: 10));

    // Three times passed while the bridge was off.
    now = now.add(const Duration(minutes: 35));
    await service.runDue();
    await pumpEventQueue();

    expect(notices.sent, hasLength(1));
    expect(notices.sent.single.notice.guidance, contains("25 minutes late"));
    expect(notices.sent.single.notice.guidance, contains("cancel_wakeup with wakeup_id ${wakeUp.id}"));
    final stored = (await wakeUps.forSession(sessionId: "s1")).single;
    expect(stored.nextDueAt, DateTime.utc(2026, 11, 15, 10, 40));
  });

  test("an occurrence is skipped while the previous one still waits for the turn", () async {
    final service = buildService();
    await schedule(service: service, when: const WakeUpEveryMinutes(minutes: 1));
    notices.gate = Completer<void>();

    now = now.add(const Duration(minutes: 1));
    await service.runDue();
    now = now.add(const Duration(minutes: 1));
    await service.runDue();
    notices.gate?.complete();
    await pumpEventQueue();

    expect(notices.sent, hasLength(1));
  });

  test("a cancel while the delivery waits sends nothing", () async {
    final service = buildService();
    final wakeUp = await schedule(service: service, when: const WakeUpInMinutes(minutes: 1));
    notices.gate = Completer<void>();
    now = now.add(const Duration(minutes: 1));
    await service.runDue();
    await pumpEventQueue();

    expect(await service.cancel(caller: _caller, wakeUpId: wakeUp.id), WakeUpCancelResult.cancelled);
    notices.gate?.complete();
    await pumpEventQueue();

    expect(notices.sent, isEmpty);
    expect(notices.outcomes, [SessionNoticeOutcome.claimLost]);
  });

  test("a one-shot whose delivery a shutdown dropped fires again after a restart", () async {
    final first = buildService();
    final wakeUp = await schedule(service: first, when: const WakeUpInMinutes(minutes: 1));
    notices.outcomeBeforeClaim = SessionNoticeOutcome.dropped;
    now = now.add(const Duration(minutes: 1));
    await first.runDue();
    await pumpEventQueue();
    expect(await wakeUps.exists(id: wakeUp.id), isTrue);

    notices.outcomeBeforeClaim = null;
    await buildService().runDue();
    await pumpEventQueue();

    expect(notices.sent, hasLength(1));
    expect(await wakeUps.exists(id: wakeUp.id), isFalse);
  });

  test("an archived session's wake-up is removed, a repeating one included", () async {
    final service = buildService();
    final wakeUp = await schedule(service: service, when: const WakeUpEveryMinutes(minutes: 5));
    notices.outcomeBeforeClaim = SessionNoticeOutcome.skippedInactive;
    now = now.add(const Duration(minutes: 5));

    await service.runDue();
    await pumpEventQueue();

    expect(await wakeUps.exists(id: wakeUp.id), isFalse);
  });

  test("deleting the session deletes its wake-ups", () async {
    final service = buildService();
    final wakeUp = await schedule(service: service, when: const WakeUpInMinutes(minutes: 5));

    await db.sessionDao.deleteSession(sessionId: "s1");

    expect(await wakeUps.exists(id: wakeUp.id), isFalse);
  });

  test("a daily wake-up keeps its local time across a daylight-saving change", () async {
    final service = buildService();
    // 09:00 in Bucharest is 06:00 UTC before 25 October 2026 and 07:00 after.
    now = DateTime.utc(2026, 10, 24, 5);
    final wakeUp = await schedule(
      service: service,
      when: const WakeUpOnSchedule(schedule: TaskSchedule.daily(time: TaskTimeOfDay(hour: 9, minute: 0))),
    );
    expect(wakeUp.nextDueAt, DateTime.utc(2026, 10, 24, 6));

    now = DateTime.utc(2026, 10, 24, 6);
    await service.runDue();
    await pumpEventQueue();

    expect(notices.sent, hasLength(1));
    expect((await wakeUps.forSession(sessionId: "s1")).single.nextDueAt, DateTime.utc(2026, 10, 25, 7));
  });

  test("a calendar wake-up is refused when the bridge cannot tell its zone", () async {
    final service = SessionWakeUpService(
      wakeUps: wakeUps,
      sessions: sessions,
      calculator: const ScheduledTaskOccurrenceCalculator(),
      notices: notices,
      descriptions: const SessionWakeUpDescriptionBuilder(),
      localTimeZone: () => null,
      clock: Clock(() => now),
    );

    final result = await service.schedule(
      caller: _caller,
      label: "Standup",
      prompt: "Summarize",
      when: const WakeUpOnSchedule(schedule: TaskSchedule.daily(time: TaskTimeOfDay(hour: 9, minute: 0))),
      timeZone: null,
    );

    expect(result, isA<WakeUpRefused>().having((refused) => refused.reason, "reason", WakeUpRefusal.timeZoneNeeded));
  });
}

/// Records the notices it sends. While [gate] is open, deliveries wait for
/// the turn to end; [outcomeBeforeClaim] ends a delivery before its claim.
class _Notices() implements SessionNoticeService {
  final List<({String sessionId, SessionNotice notice, SessionNoticeTiming timing})> sent = [];
  final List<SessionNoticeOutcome> outcomes = [];
  Completer<void>? gate;
  SessionNoticeOutcome? outcomeBeforeClaim;

  @override
  Future<SessionNoticeOutcome> deliver({
    required String sessionId,
    required SessionNotice notice,
    required SessionNoticeTiming timing,
    required Future<bool> Function()? claim,
  }) async {
    await gate?.future;
    final outcome = await _outcome(claim: claim);
    outcomes.add(outcome);
    if (outcome == SessionNoticeOutcome.sent) sent.add((sessionId: sessionId, notice: notice, timing: timing));
    return outcome;
  }

  Future<SessionNoticeOutcome> _outcome({required Future<bool> Function()? claim}) async {
    if (outcomeBeforeClaim case final early?) return early;
    if (claim != null && !await claim()) return SessionNoticeOutcome.claimLost;
    return SessionNoticeOutcome.sent;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
