import "dart:async";
import "dart:convert";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _userA = AuthUser(
  id: "user-a",
  provider: AuthProvider.github,
  providerUserId: "github-a",
  providerUsername: "alpha",
);
const _userB = AuthUser(
  id: "user-b",
  provider: AuthProvider.google,
  providerUserId: "google-b",
  providerUsername: "beta",
);
const _userKey = "user-key-that-must-not-be-sent";
const _transient = ProductAnalyticsEventClientResult.transientFailure(
  description: 'HTTP 503: {"error":"unavailable"}',
  cause: null,
  stackTrace: null,
);
const _permanent = ProductAnalyticsEventClientResult.permanentFailure(
  description: 'HTTP 400: {"error":"bad_request"}',
  cause: null,
);
const _delivered = ProductAnalyticsEventClientResult.delivered();

final _occurredAtUtc = DateTime.fromMicrosecondsSinceEpoch(1793232000000000, isUtc: true);

class _MockAuthSession() extends Mock implements AuthSession;

class _MockAppInfoSource() extends Mock implements DesktopAppInfoSource;

class _RecordingLogSink() implements LogSink {
  final List<LogRecord> records = [];

  @override
  void write({required LogRecord record}) => records.add(record);

  @override
  Future<void> flush() async {}
}

/// Answers each attempt from [results], then keeps answering with the last one.
class _FakeEventClient({required final List<ProductAnalyticsEventClientResult> results})
    implements ProductAnalyticsEventClient {
  final List<({String userId, ProductAnalyticsEventRequest request})> attempts = [];
  Future<ProductAnalyticsEventClientResult>? never;
  void Function({required int attempt})? onAttempt;

  @override
  Future<ProductAnalyticsEventClientResult> send({
    required String userId,
    required ProductAnalyticsEventRequest request,
  }) async {
    attempts.add((userId: userId, request: request));
    onAttempt?.call(attempt: attempts.length);
    final pending = never;
    if (pending != null) return await pending;
    return results[attempts.length > results.length ? results.length - 1 : attempts.length - 1];
  }
}

void main() {
  late _MockAuthSession authSession;
  late _MockAppInfoSource appInfo;
  late _RecordingLogSink logs;

  AuthServerAnalyticsClient clientFor({required _FakeEventClient events}) =>
      AuthServerAnalyticsClient(eventClient: events, authSession: authSession, appInfoSource: appInfo);

  ProductAnalyticsEnvelope envelopeOf({required ProductAnalyticsEvent event}) =>
      ProductAnalyticsEnvelope(event: event, occurredAtUtc: _occurredAtUtc);

  const sampleEvent = ProductAnalyticsEvent.sessionMessageSent(
    submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
  );

  Future<void> logSample({required AuthServerAnalyticsClient client}) => client.logProductEvent(
    envelope: envelopeOf(event: sampleEvent),
    userKey: _userKey,
  );

  setUp(() {
    authSession = _MockAuthSession();
    when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _userA));
    appInfo = _MockAppInfoSource();
    when(() => appInfo.platform).thenReturn(ProductAnalyticsEventPlatform.macos);
    when(() => appInfo.readVersion()).thenAnswer((_) async => "1.11.0");
    logs = _RecordingLogSink();
    setLogSink(sink: logs);
  });

  tearDown(() => setLogSink(sink: const StdoutLogSink()));

  group("pinned contract", () {
    test("sends the exact body, and never the user key", () async {
      final events = _FakeEventClient(results: [_delivered]);

      await logSample(client: clientFor(events: events));
      await pumpEventQueue();

      expect(events.attempts.single.userId, _userA.id);
      final body = jsonEncode(events.attempts.single.request.toJson());
      expect(jsonDecode(body), {
        "schemaVersion": 1,
        "platform": "MACOS",
        "appVersion": "1.11.0",
        "name": "session_message_sent",
        "occurredAtMicros": 1793232000000000,
        "params": {"submission_kind": "text", "input_mode": "typed"},
      });
      expect(body, isNot(contains(_userKey)));
    });

    const surface = OnboardingSurface.connectSetup;
    final sentEvents = <({ProductAnalyticsEvent event, String name, Map<String, String> params})>[
      (event: const ProductAnalyticsEvent.analyticsSchemaReady(), name: "analytics_schema_ready", params: const {}),
      (
        event: const ProductAnalyticsEvent.analyticsActivationReady(),
        name: "analytics_activation_ready",
        params: const {"activation_schema_version": "1"},
      ),
      (
        event: const ProductAnalyticsEvent.projectInventoryLoaded(inventoryState: AnalyticsInventoryState.nonEmpty),
        name: "project_inventory_loaded",
        params: const {"inventory_state": "non_empty"},
      ),
      (
        event: const ProductAnalyticsEvent.sessionActivityViewed(activityState: AnalyticsActivityState.empty),
        name: "session_activity_viewed",
        params: const {"activity_state": "empty"},
      ),
      (
        event: const ProductAnalyticsEvent.sessionMessageSent(submission: AnalyticsSubmission.command()),
        name: "session_message_sent",
        params: const {"submission_kind": "command", "input_mode": "typed"},
      ),
      (
        event: const ProductAnalyticsEvent.sessionCreatedWithMessage(
          submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.voiceAssisted),
          workspaceKind: AnalyticsWorkspaceKind.dedicatedWorktree,
        ),
        name: "session_created_with_message",
        params: const {
          "submission_kind": "text",
          "input_mode": "voice_assisted",
          "workspace_kind": "dedicated_worktree",
        },
      ),
      (
        event: const ProductAnalyticsEvent.sessionCreationFailed(
          failureReason: AnalyticsSessionCreationFailureReason.networkDown,
          workspaceKind: AnalyticsWorkspaceKind.noProject,
        ),
        name: "session_creation_failed",
        params: const {"failure_reason": "network_down", "workspace_kind": "no_project"},
      ),
      (
        event: const ProductAnalyticsEvent.voiceTranscriptionCompleted(
          finish: AnalyticsVoiceFinish.sent,
          mode: AnalyticsVoiceMode.onDevice,
        ),
        name: "voice_transcription_completed",
        params: const {},
      ),
      (
        event: const ProductAnalyticsEvent.sessionQuestionAnswered(),
        name: "session_question_answered",
        params: const {},
      ),
      (
        event: const ProductAnalyticsEvent.sessionQuestionRejected(),
        name: "session_question_rejected",
        params: const {},
      ),
      (
        event: const ProductAnalyticsEvent.sessionPermissionAnswered(decision: AnalyticsPermissionDecision.always),
        name: "session_permission_answered",
        params: const {"decision": "always"},
      ),
      (event: const ProductAnalyticsEvent.sessionAbortSucceeded(), name: "session_abort_succeeded", params: const {}),
      (
        event: const ProductAnalyticsEvent.sessionDiffViewed(changeState: AnalyticsChangeState.nonEmpty),
        name: "session_diff_viewed",
        params: const {"change_state": "non_empty"},
      ),
      (
        event: const ProductAnalyticsEvent.feedbackPromptAnswered(
          answer: AnalyticsFeedbackAnswer.loveReviewRequested,
          source: AnalyticsFeedbackSource.automatic,
        ),
        name: "feedback_prompt_answered",
        params: const {"answer": "love_review_requested", "source": "automatic"},
      ),
      (
        event: const ProductAnalyticsEvent.privateFeedbackSent(
          input: AnalyticsFeedbackInput.issuesOnly,
          source: AnalyticsFeedbackSource.settings,
        ),
        name: "private_feedback_sent",
        params: const {"input": "issues_only", "source": "settings"},
      ),
      (
        event: const ProductAnalyticsEvent.needHelpMenuOpened(surface: surface),
        name: "onboarding_need_help_opened",
        params: const {"surface": "connect_setup"},
      ),
      (
        event: const ProductAnalyticsEvent.supportLinkOpened(channel: SupportChannel.discord, surface: surface),
        name: "onboarding_support_link_opened",
        params: const {"surface": "connect_setup", "channel": "discord"},
      ),
      (
        event: const ProductAnalyticsEvent.whyBridgeOpened(surface: surface),
        name: "onboarding_why_bridge_opened",
        params: const {"surface": "connect_setup"},
      ),
      (
        event: const ProductAnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.powershell,
          os: BridgeInstallOs.windows,
          surface: surface,
        ),
        name: "bridge_install_command_copied",
        params: const {"surface": "connect_setup", "method": "powershell", "os": "windows"},
      ),
      (
        event: const ProductAnalyticsEvent.installCommandShared(
          method: BridgeInstallMethod.curl,
          os: BridgeInstallOs.unix,
          surface: surface,
        ),
        name: "bridge_install_command_shared",
        params: const {"surface": "connect_setup", "method": "curl", "os": "unix"},
      ),
      (
        event: const ProductAnalyticsEvent.runCommandCopied(surface: surface),
        name: "bridge_run_command_copied",
        params: const {"surface": "connect_setup"},
      ),
      (
        event: const ProductAnalyticsEvent.runCommandShared(surface: surface),
        name: "bridge_run_command_shared",
        params: const {"surface": "connect_setup"},
      ),
      (
        event: const ProductAnalyticsEvent.screenViewed(screen: AnalyticsScreen.sessionDetail),
        name: "product_screen_viewed",
        params: const {"screen": "session_detail"},
      ),
    ];

    test("covers all 23 event names in the contract", () {
      expect(sentEvents.map((event) => event.name).toSet(), hasLength(23));
    });

    for (final sent in sentEvents) {
      test("sends ${sent.name} with exactly its params, within the 1 KiB limit", () async {
        final events = _FakeEventClient(results: [_delivered]);

        await clientFor(events: events).logProductEvent(
          envelope: envelopeOf(event: sent.event),
          userKey: _userKey,
        );
        await pumpEventQueue();

        final request = events.attempts.single.request;
        expect(request.name, sent.name);
        expect(request.params, sent.params);
        expect(utf8.encode(jsonEncode(request.toJson())).length, lessThan(1024));
      });
    }

    final notSentEvents = <({ProductAnalyticsEvent event, String reason})>[
      (
        event: const ProductAnalyticsEvent.harnessInstallFinished(outcome: AnalyticsHarnessInstallOutcome.completed),
        reason: "harness_install_finished",
      ),
      (
        event: const ProductAnalyticsEvent.transcriptPromptsOpened(entry: AnalyticsPromptsEntry.sessionBar),
        reason: "transcript_prompts_opened",
      ),
      (
        event: const ProductAnalyticsEvent.computerSwitched(source: ComputerSwitchSource.menu, targetOnline: true),
        reason: "computer_switched",
      ),
      (
        event: const ProductAnalyticsEvent.computerManaged(action: ComputerManageAction.renamed),
        reason: "computer_managed",
      ),
      (
        event: const ProductAnalyticsEvent.founderCallShown(surface: FounderCallSurface.settings),
        reason: "founder_call_shown",
      ),
      (
        event: const ProductAnalyticsEvent.founderCallLinkOpened(surface: FounderCallSurface.settings),
        reason: "founder_call_link_opened",
      ),
      (
        event: const ProductAnalyticsEvent.founderCallDeclined(surface: FounderCallSurface.settings),
        reason: "founder_call_declined",
      ),
    ];

    for (final notSent in notSentEvents) {
      test("doesn't send ${notSent.reason}, which is outside the warehouse allowlist", () async {
        final events = _FakeEventClient(results: [_delivered]);

        await clientFor(events: events).logProductEvent(
          envelope: envelopeOf(event: notSent.event),
          userKey: _userKey,
        );
        await pumpEventQueue();

        expect(notSent.event.wireName, notSent.reason);
        expect(events.attempts, isEmpty);
      });
    }

    // The server's enums are closed, so a client value the contract doesn't
    // list would be rejected with a 400 and lost.
    final closedValues = <({Iterable<String> client, Set<String> contract})>[
      (
        client: AnalyticsInventoryState.values.map((value) => value.wireValue),
        contract: const {"empty", "non_empty"},
      ),
      (
        client: AnalyticsActivityState.values.map((value) => value.wireValue),
        contract: const {"empty", "non_empty"},
      ),
      (
        client: AnalyticsSubmissionKind.values.map((value) => value.wireValue),
        contract: const {"text", "command"},
      ),
      (
        client: AnalyticsInputMode.values.map((value) => value.wireValue),
        contract: const {"typed", "voice_assisted"},
      ),
      (
        client: AnalyticsWorkspaceKind.values.map((value) => value.wireValue),
        contract: const {"project", "dedicated_worktree", "no_project"},
      ),
      (
        client: AnalyticsSessionCreationFailureReason.values.map((value) => value.wireValue),
        contract: const {"not_authenticated", "server_rejected", "network_down", "bad_response", "unknown"},
      ),
      (
        client: AnalyticsPermissionDecision.values.map((value) => value.wireValue),
        contract: const {"once", "always", "reject"},
      ),
      (
        client: AnalyticsChangeState.values.map((value) => value.wireValue),
        contract: const {"empty", "non_empty"},
      ),
      (
        client: AnalyticsFeedbackAnswer.values.map((value) => value.wireValue),
        contract: const {"love_review_requested", "love_no_review", "could_be_better", "dismissed"},
      ),
      (
        client: AnalyticsFeedbackInput.values.map((value) => value.wireValue),
        contract: const {"typed", "voice_assisted", "issues_only", "empty"},
      ),
      (
        client: AnalyticsFeedbackSource.values.map((value) => value.wireValue),
        contract: const {"automatic", "settings"},
      ),
      (
        client: OnboardingSurface.values.map((value) => value.wireValue),
        contract: const {"connect_setup", "connected_empty", "bridge_offline"},
      ),
      (
        client: SupportChannel.values.map((value) => value.wireValue),
        contract: const {"email", "discord", "x"},
      ),
      (
        client: BridgeInstallMethod.values.map((value) => value.wireValue),
        contract: const {"curl", "powershell", "npm", "bun"},
      ),
      (
        client: BridgeInstallOs.values.map((value) => value.wireValue),
        contract: const {"unix", "windows"},
      ),
      (
        client: AnalyticsScreen.values.map((value) => value.wireValue),
        contract: const {
          "login",
          "projects",
          "settings",
          "settings_default_input",
          "settings_notifications",
          "settings_profile",
          "sessions",
          "new_session",
          "session_detail",
          "session_diffs",
        },
      ),
    ];

    test("every client enum value is one the contract's closed sets accept", () {
      for (final values in closedValues) {
        expect(values.client, everyElement(isIn(values.contract)));
      }
    });
  });

  group("platform", () {
    for (final (platform, wire) in const [
      (ProductAnalyticsEventPlatform.macos, "MACOS"),
      (ProductAnalyticsEventPlatform.linux, "LINUX"),
      (ProductAnalyticsEventPlatform.windows, "WINDOWS"),
    ]) {
      test("$platform reports $wire", () async {
        when(() => appInfo.platform).thenReturn(platform);
        final events = _FakeEventClient(results: [_delivered]);

        await logSample(client: clientFor(events: events));
        await pumpEventQueue();

        expect(events.attempts.single.request.toJson()["platform"], wire);
      });
    }

    test("no desktop OS sends nothing", () async {
      when(() => appInfo.platform).thenReturn(null);
      final events = _FakeEventClient(results: [_delivered]);

      await logSample(client: clientFor(events: events));
      await pumpEventQueue();

      expect(events.attempts, isEmpty);
    });
  });

  group("app version", () {
    test("removes a build suffix", () async {
      when(() => appInfo.readVersion()).thenAnswer((_) async => "1.11.0+1066");
      final events = _FakeEventClient(results: [_delivered]);

      await logSample(client: clientFor(events: events));
      await pumpEventQueue();

      expect(events.attempts.single.request.appVersion, "1.11.0");
    });

    test("is read once", () async {
      final events = _FakeEventClient(results: [_delivered]);
      final client = clientFor(events: events);

      await logSample(client: client);
      await logSample(client: client);
      await pumpEventQueue();

      expect(events.attempts, hasLength(2));
      verify(() => appInfo.readVersion()).called(1);
    });

    test("a failed read warns once with the error, and each dropped event is named", () async {
      when(() => appInfo.readVersion()).thenAnswer((_) async => throw StateError("no package info"));
      final events = _FakeEventClient(results: [_delivered]);
      final client = clientFor(events: events);

      await logSample(client: client);
      await logSample(client: client);
      await pumpEventQueue();

      expect(events.attempts, isEmpty);
      expect(logs.records.map((record) => record.level), everyElement(LogLevel.warning));
      final [readFailure, firstDrop, secondDrop] = logs.records;
      expect(readFailure.diagnosticError, contains("no package info"));
      expect(readFailure.stackTrace, isNotNull);
      for (final drop in [firstDrop, secondDrop]) {
        expect(drop.message, contains("session_message_sent"));
        expect(drop.diagnosticError, isNull);
      }
      verify(() => appInfo.readVersion()).called(1);
    });
  });

  group("not blocking the caller", () {
    test("returns before a POST that never completes", () async {
      final events = _FakeEventClient(results: [_delivered]);
      events.never = Completer<ProductAnalyticsEventClientResult>().future;

      await logSample(client: clientFor(events: events));
      await pumpEventQueue();

      expect(events.attempts, hasLength(1));
    });

    test("returns before an app version read that never completes", () async {
      when(() => appInfo.readVersion()).thenAnswer((_) => Completer<String>().future);
      final events = _FakeEventClient(results: [_delivered]);

      await logSample(client: clientFor(events: events));

      expect(events.attempts, isEmpty);
    });

    test("a failed send never reaches the caller", () async {
      final events = _FakeEventClient(results: [_permanent]);

      await expectLater(logSample(client: clientFor(events: events)), completes);
      await pumpEventQueue();

      expect(events.attempts, hasLength(1));
    });
  });

  group("retry", () {
    test("waits 5 and then 30 seconds, and stops after 3 attempts", () {
      fakeAsync((async) {
        final events = _FakeEventClient(results: [_transient]);
        unawaited(logSample(client: clientFor(events: events)));
        async.flushMicrotasks();
        expect(events.attempts, hasLength(1));

        async.elapse(const Duration(seconds: 4, milliseconds: 999));
        expect(events.attempts, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(events.attempts, hasLength(2));

        async.elapse(const Duration(seconds: 29, milliseconds: 999));
        expect(events.attempts, hasLength(2));
        async.elapse(const Duration(milliseconds: 1));
        expect(events.attempts, hasLength(3));

        async.elapse(const Duration(hours: 1));
        expect(events.attempts, hasLength(3));
        expect(async.pendingTimers, isEmpty);
      });
    });

    test("stops once an attempt is delivered", () {
      fakeAsync((async) {
        final events = _FakeEventClient(results: [_transient, _delivered]);
        unawaited(logSample(client: clientFor(events: events)));

        async.elapse(const Duration(hours: 1));

        expect(events.attempts, hasLength(2));
      });
    });

    test("stops at a permanent failure reached during a retry", () {
      fakeAsync((async) {
        final events = _FakeEventClient(results: [_transient, _permanent]);
        unawaited(logSample(client: clientFor(events: events)));

        async.elapse(const Duration(hours: 1));

        expect(events.attempts, hasLength(2));
      });
    });

    test("doesn't retry a permanent failure", () {
      fakeAsync((async) {
        final events = _FakeEventClient(results: [_permanent]);
        unawaited(logSample(client: clientFor(events: events)));

        async.elapse(const Duration(hours: 1));

        expect(events.attempts, hasLength(1));
        expect(async.pendingTimers, isEmpty);
      });
    });

    test("resends the same request with the same occurrence time", () {
      fakeAsync((async) {
        final events = _FakeEventClient(results: [_transient]);
        unawaited(logSample(client: clientFor(events: events)));

        async.elapse(const Duration(hours: 1));

        expect(events.attempts.map((attempt) => attempt.request).toSet(), hasLength(1));
        expect(events.attempts.first.request.occurredAtMicros, _occurredAtUtc.microsecondsSinceEpoch);
      });
    });

    for (final (name, state) in const [
      ("signs out", AuthState.unauthenticated()),
      ("is replaced by another account", AuthState.authenticated(user: _userB)),
    ]) {
      test("stops before a retry once the account $name, logging at info and no error", () {
        fakeAsync((async) {
          final events = _FakeEventClient(results: [_transient]);
          unawaited(logSample(client: clientFor(events: events)));
          async.flushMicrotasks();

          when(() => authSession.currentState).thenReturn(state);
          async.elapse(const Duration(hours: 1));

          expect(events.attempts, hasLength(1));
          expect(logs.records.map((record) => record.level), [LogLevel.warning, LogLevel.info]);
          expect(logs.records.last.message, contains("session_message_sent"));
          expect(async.pendingTimers, isEmpty);
        });
      });
    }

    test("a sign-out during the last attempt logs at info, not as giving up", () {
      fakeAsync((async) {
        final events = _FakeEventClient(results: [_transient]);
        events.onAttempt = ({required attempt}) {
          if (attempt == 3) when(() => authSession.currentState).thenReturn(const AuthState.unauthenticated());
        };
        unawaited(logSample(client: clientFor(events: events)));

        async.elapse(const Duration(hours: 1));

        expect(events.attempts, hasLength(3));
        expect(logs.records.map((record) => record.level), [LogLevel.warning, LogLevel.warning, LogLevel.info]);
      });
    });
  });

  group("signed-out account", () {
    test("sends nothing and logs the event name", () async {
      when(() => authSession.currentState).thenReturn(const AuthState.unauthenticated());
      final events = _FakeEventClient(results: [_delivered]);

      await logSample(client: clientFor(events: events));
      await pumpEventQueue();

      expect(events.attempts, isEmpty);
      expect(logs.records.single.message, contains("session_message_sent"));
    });
  });

  group("logging", () {
    void expectDiagnostics({required LogRecord record, required LogLevel level, required String description}) {
      expect(record.level, level);
      expect(record.message, contains("session_message_sent"));
      expect(record.message, contains(description));
      for (final leaked in [_userA.id, _userKey, "submission_kind", "input_mode", "typed", "1.11.0"]) {
        expect(record.formatted, isNot(contains(leaked)));
      }
    }

    test("a 400 logs the event name, status and response body, and no error it doesn't have", () async {
      await logSample(
        client: clientFor(events: _FakeEventClient(results: [_permanent])),
      );
      await pumpEventQueue();

      final record = logs.records.single;
      expectDiagnostics(record: record, level: LogLevel.error, description: 'HTTP 400: {"error":"bad_request"}');
      expect(record.diagnosticError, isNull);
      expect(record.stackTrace, isNull);
    });

    test("a permanent failure keeps its original error", () async {
      await logSample(
        client: clientFor(
          events: _FakeEventClient(
            results: [
              const ProductAnalyticsEventClientResult.permanentFailure(
                description: "unusable response",
                cause: FormatException("not json"),
              ),
            ],
          ),
        ),
      );
      await pumpEventQueue();

      final record = logs.records.single;
      expectDiagnostics(record: record, level: LogLevel.error, description: "unusable response");
      expect(record.diagnosticError, contains("not json"));
    });

    test("each failed attempt logs its category, original error and stack trace", () {
      fakeAsync((async) {
        final stackTrace = StackTrace.fromString("the original stack");
        unawaited(
          logSample(
            client: clientFor(
              events: _FakeEventClient(
                results: [
                  ProductAnalyticsEventClientResult.transientFailure(
                    description: "no response",
                    cause: TimeoutException("attempt deadline"),
                    stackTrace: stackTrace,
                  ),
                ],
              ),
            ),
          ),
        );

        async.elapse(const Duration(hours: 1));

        expect(logs.records.map((record) => record.level), [LogLevel.warning, LogLevel.warning, LogLevel.error]);
        for (final record in logs.records) {
          expectDiagnostics(record: record, level: record.level, description: "no response");
          expect(record.diagnosticError, contains("attempt deadline"));
          expect(record.stackTrace, stackTrace);
        }
      });
    });

    test("a transient status names the status once the retries run out", () {
      fakeAsync((async) {
        unawaited(
          logSample(
            client: clientFor(events: _FakeEventClient(results: [_transient])),
          ),
        );

        async.elapse(const Duration(hours: 1));

        expectDiagnostics(
          record: logs.records.last,
          level: LogLevel.error,
          description: 'HTTP 503: {"error":"unavailable"}',
        );
      });
    });

    test("a failure that a retry recovers from stays visible as a warning", () {
      fakeAsync((async) {
        unawaited(
          logSample(
            client: clientFor(events: _FakeEventClient(results: [_transient, _delivered])),
          ),
        );

        async.elapse(const Duration(hours: 1));

        expectDiagnostics(
          record: logs.records.single,
          level: LogLevel.warning,
          description: 'HTTP 503: {"error":"unavailable"}',
        );
      });
    });
  });

  test("the installation and activation calls send nothing", () async {
    final events = _FakeEventClient(results: [_delivered]);
    final client = clientFor(events: events);

    await client.logInstallationEvent(
      event: const InstallationAnalyticsEvent.loginAttemptStarted(provider: AnalyticsLoginProvider.github),
    );
    await client.activateAfterInteractiveAuthentication();
    await pumpEventQueue();

    expect(events.attempts, isEmpty);
  });
}
