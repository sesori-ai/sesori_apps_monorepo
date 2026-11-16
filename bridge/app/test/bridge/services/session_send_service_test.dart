import "dart:async";
import "dart:convert";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/repositories/mappers/session_transcript_markdown_builder.dart";
import "package:sesori_bridge/src/repositories/models/history_window.dart";
import "package:sesori_bridge/src/repositories/models/normalized_bridge_event.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/permission_repository.dart";
import "package:sesori_bridge/src/repositories/prompt_upload_repository.dart";
import "package:sesori_bridge/src/repositories/question_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/chat_history_service.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_bridge/src/services/session_abort_service.dart";
import "package:sesori_bridge/src/services/session_event_dispatcher.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_prompt_refused_exception.dart";
import "package:sesori_bridge/src/services/session_prompt_service.dart";
import "package:sesori_bridge/src/services/session_send_rejected_exception.dart";
import "package:sesori_bridge/src/services/session_send_service.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_bridge/src/services/stale_session_prompt_options_exception.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeSseSessionError,
        BridgeSseSessionIdle,
        Log,
        LogLevel,
        PluginOperationException,
        PluginRefusalException,
        PluginStaleOptionsException;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/log_capture.dart";

const _source = "source";
const _target = "target";
const _requestMessageId = "msg-summary-request";
const _summary = "Fixture summary: the login fix is half done.";
const _transcriptLine = "Fixture transcript line about the login form.";

void main() {
  late _Sessions sessions;
  late _Prompts prompts;
  late _Events events;
  late _Aborts aborts;
  late _History history;
  late _Transcripts transcripts;
  late _Questions questions;
  late SessionOperationDispatcher operations;
  late SessionSendService service;

  SessionSendService buildService({required Duration summaryTimeout}) => SessionSendService(
    sessions: sessions,
    views: _Views(sessions: sessions),
    permissions: const _Permissions(),
    questions: questions,
    operations: operations,
    prompts: prompts,
    events: events,
    aborts: aborts,
    history: history,
    transcripts: transcripts,
    markdown: const SessionTranscriptMarkdownBuilder(),
    plugins: const _Plugins(),
    clock: Clock.fixed(DateTime.utc(2026, 11, 15, 12)),
    summaryTimeout: summaryTimeout,
  );

  setUp(() {
    sessions = _Sessions();
    prompts = _Prompts();
    events = _Events();
    aborts = _Aborts();
    history = _History();
    transcripts = _Transcripts();
    questions = _Questions();
    operations = SessionOperationDispatcher(sessionRepository: sessions);
    service = buildService(summaryTimeout: const Duration(minutes: 15));
    history.messages = [
      _userMessage(id: "msg-1", text: _transcriptLine),
      _assistantMessage(id: "msg-2", text: "Fixture reply."),
      _userMessage(id: _requestMessageId, text: "summary request"),
      _assistantMessage(id: "msg-4", text: _summary),
    ];
  });
  tearDown(() async {
    await operations.dispose();
    await events.close();
    await aborts.close();
  });

  /// Plays the source's summary turn once the summary request is accepted.
  void finishSummaryTurn() {
    prompts.onSummaryAccepted = (promptId) {
      events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
      events.add(const NormalizedStatusEvent(sessionId: _source, status: SessionStatus.idle()));
    };
  }

  Future<SendToSessionErrorCode> refusalOf(Future<void> send) async {
    try {
      await send;
    } on SessionSendRejectedException catch (error) {
      return error.code;
    }
    fail("the send succeeded");
  }

  Future<void> send() => service.send(sourceSessionId: _source, targetSessionId: _target);

  test("sends the summary to the target with the saved transcript path", () async {
    finishSummaryTurn();

    await send();

    final request = prompts.sends.first;
    expect(request.sessionId, _source);
    expect(request.reserved, isTrue);
    expect(request.text, contains('"Target title"'));
    expect(request.agent, "plan");
    expect(request.model, const PromptModel(providerID: "anthropic", modelID: "opus"));
    expect(request.variant, const SessionVariant(id: "high"));
    expect(request.fastMode, isTrue);
    expect(history.backfilled, [_source]);

    final saved = transcripts.saved.single;
    expect(saved.sessionId, _target);
    expect(saved.filename, "Source title.md");
    final markdown = utf8.decode(saved.bytes);
    expect(markdown, contains(_transcriptLine));
    expect(markdown, contains("Harness: Claude Code"));
    expect(markdown, isNot(contains(_summary)));

    final handoff = prompts.sends.last;
    expect(prompts.sends, hasLength(2));
    expect(handoff.sessionId, _target);
    expect(handoff.reserved, isFalse);
    expect(handoff.agent, isNull);
    expect(handoff.model, isNull);
    expect(handoff.text, contains('"Source title" (Claude Code, in `/fixture/source`)'));
    expect(handoff.text, contains(_summary));
    expect(handoff.text, contains("`${transcripts.pathFor(saved)}`"));

    expect(request.handoff, const MessageHandoff.sent(targetSessionId: _target, targetTitle: "Target title"));
    expect(
      handoff.handoff,
      MessageHandoff.received(
        sourceSessionId: _source,
        sourceTitle: "Source title",
        summary: _summary,
        transcriptPath: transcripts.pathFor(saved),
      ),
    );
    expect(sessions.notSentPrompts, isEmpty);
    expect(history.notSentMessages, isEmpty);
  });

  test("the transcript leaves out the summary exchanges of earlier sends", () async {
    finishSummaryTurn();
    const earlierTarget = MessageHandoff.sent(targetSessionId: "earlier", targetTitle: null);
    const failedTarget = MessageHandoff.notSent(targetSessionId: "failed", targetTitle: null);
    history.messages = [
      _userMessage(id: "msg-1", text: _transcriptLine),
      _userMessage(id: "sent-request", text: "Earlier sent request", handoff: earlierTarget),
      _assistantMessage(id: "sent-reply", text: "Earlier sent summary"),
      _userMessage(id: "after-sent", text: "Typed after the sent summary"),
      _assistantMessage(id: "after-sent-reply", text: "Reply after the sent summary"),
      _userMessage(id: "failed-request", text: "Earlier failed request", handoff: failedTarget),
      _assistantMessage(id: "failed-reply", text: "Earlier failed summary"),
      _userMessage(
        id: "received",
        text: "Received handoff prompt",
        handoff: const MessageHandoff.received(
          sourceSessionId: "elsewhere",
          sourceTitle: null,
          summary: "Received summary",
          transcriptPath: "/fixture/received.md",
        ),
      ),
      _assistantMessage(id: "received-reply", text: "Reply to the received handoff"),
      _userMessage(id: _requestMessageId, text: "summary request"),
      _assistantMessage(id: "msg-4", text: _summary),
    ];

    await send();

    final markdown = utf8.decode(transcripts.saved.single.bytes);
    for (final kept in [
      _transcriptLine,
      "Typed after the sent summary",
      "Reply after the sent summary",
      "Received handoff prompt",
      "Reply to the received handoff",
    ]) {
      expect(markdown, contains(kept));
    }
    for (final dropped in [
      "Earlier sent request",
      "Earlier sent summary",
      "Earlier failed request",
      "Earlier failed summary",
      "summary request",
    ]) {
      expect(markdown, isNot(contains(dropped)));
    }
  });

  group("a send that does not complete marks its summary request as not sent", () {
    void echoThen(List<NormalizedBridgeEvent> followUps) {
      prompts.onSummaryAccepted = (promptId) {
        events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
        followUps.forEach(events.add);
      };
    }

    const idle = NormalizedStatusEvent(sessionId: _source, status: SessionStatus.idle());
    final afterEcho = <String, (SendToSessionErrorCode, void Function())>{
      // The echo reaches the watch asynchronously; the stop comes after it.
      "a stop": (
        SendToSessionErrorCode.summaryStopped,
        () {
          prompts.onSummaryAccepted = (promptId) {
            events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
            Future(() => aborts.add(_source)).ignore();
          };
        },
      ),
      "a session error": (
        SendToSessionErrorCode.summaryFailed,
        () => echoThen([const NormalizedOtherEvent(event: BridgeSseSessionError(sessionID: _source))]),
      ),
      "a plugin stop": (
        SendToSessionErrorCode.summaryFailed,
        () => echoThen([const NormalizedTerminalHandoff(payload: idle)]),
      ),
      "an error message": (
        SendToSessionErrorCode.summaryFailed,
        () => echoThen([
          const NormalizedMessageEvent(
            message: Message.error(
              id: "turn-1",
              sessionID: _source,
              agent: null,
              modelID: null,
              providerID: null,
              errorName: "FixtureError",
              errorMessage: "fixture failure",
              time: null,
            ),
          ),
          idle,
        ]),
      ),
      "bridge shutdown": (
        SendToSessionErrorCode.summaryStopped,
        () {
          prompts.onSummaryAccepted = (promptId) {
            events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
            Future(service.beginShutdown).ignore();
          };
        },
      ),
      "a timeout": (
        SendToSessionErrorCode.summaryTimedOut,
        () {
          service = buildService(summaryTimeout: const Duration(milliseconds: 20));
          echoThen([]);
        },
      ),
      "a missing summary": (
        SendToSessionErrorCode.summaryMissing,
        () {
          echoThen([idle]);
          history.messages = history.messages.take(3).toList();
        },
      ),
      "a failed transcript write": (
        SendToSessionErrorCode.transcriptUnavailable,
        () {
          echoThen([idle]);
          transcripts.failure = const FormatException("disk full");
        },
      ),
      "a target refusal": (
        SendToSessionErrorCode.targetRefused,
        () {
          echoThen([idle]);
          prompts.targetFailure = StateError("target down");
        },
      ),
    };
    for (final MapEntry(key: name, value: (code, arrange)) in afterEcho.entries) {
      test("after the echo: $name", () async {
        arrange();

        expect(await refusalOf(send()), code);
        expect(sessions.notSentPrompts, [prompts.sends.first.promptId]);
        expect(history.notSentMessages, [_requestMessageId]);
      });
    }

    final afterReplay = <String, (SendToSessionErrorCode, void Function())>{
      "a target refusal": (
        SendToSessionErrorCode.targetRefused,
        () => prompts.targetFailure = StateError("target down"),
      ),
      "a missing summary": (
        SendToSessionErrorCode.summaryMissing,
        () => history.messages = history.messages.take(3).toList(),
      ),
    };
    for (final MapEntry(key: name, value: (code, arrange)) in afterReplay.entries) {
      test("after a refresh replays the request under another id, $name marks both ids", () async {
        finishSummaryTurn();
        history.replayRequestText = () => prompts.sends.first.text;
        arrange();

        expect(await refusalOf(send()), code);
        expect(history.notSentMessages, unorderedEquals(["replayed-user", _requestMessageId]));
      });
    }

    final beforeEcho = <String, (SendToSessionErrorCode, void Function())>{
      "a stop": (
        SendToSessionErrorCode.summaryStopped,
        () {
          prompts.onSummaryAccepted = (_) => aborts.add(_source);
        },
      ),
      "a session error": (
        SendToSessionErrorCode.summaryFailed,
        () {
          prompts.onSummaryAccepted = (_) => events.add(
            const NormalizedOtherEvent(event: BridgeSseSessionError(sessionID: _source)),
          );
        },
      ),
      "a timeout": (
        SendToSessionErrorCode.summaryTimedOut,
        () {
          service = buildService(summaryTimeout: const Duration(milliseconds: 20));
        },
      ),
      "a request whose outcome is unknown": (
        SendToSessionErrorCode.sourceUnavailable,
        () {
          prompts.summaryFailure = StateError("plugin timed out");
        },
      ),
    };
    for (final MapEntry(key: name, value: (code, arrange)) in beforeEcho.entries) {
      test("before the echo: $name", () async {
        arrange();

        expect(await refusalOf(send()), code);
        expect(sessions.notSentPrompts, hasLength(1));
        expect(history.notSentMessages, isEmpty);
      });
    }
  });

  group("refuses before sending anything", () {
    final cases = <String, (SendToSessionErrorCode, void Function(_Sessions sessions, _Questions questions))>{
      "the same session": (SendToSessionErrorCode.sameSession, (_, _) {}),
      "an archived source": (
        SendToSessionErrorCode.sourceArchived,
        (sessions, _) => sessions.archive(sessionId: _source),
      ),
      "an archived target": (
        SendToSessionErrorCode.targetArchived,
        (sessions, _) => sessions.archive(sessionId: _target),
      ),
      "a child source": (
        SendToSessionErrorCode.sourceNotRoot,
        (sessions, _) => sessions.reparent(sessionId: _source),
      ),
      "a busy source": (
        SendToSessionErrorCode.sourceBusy,
        (sessions, _) => sessions.statuses[_source] = const SessionStatus.busy(since: null),
      ),
      "a retrying source": (
        SendToSessionErrorCode.sourceBusy,
        (sessions, _) => sessions.statuses[_source] = const SessionStatus.retry(
          attempt: 1,
          message: "rate limited",
          next: 0,
          since: null,
        ),
      ),
      "a source waiting for an answer": (
        SendToSessionErrorCode.sourceAwaitingInput,
        (_, questions) => questions.pending = true,
      ),
    };
    for (final MapEntry(key: name, value: (code, arrange)) in cases.entries) {
      test(name, () async {
        arrange(sessions, questions);
        final target = code == SendToSessionErrorCode.sameSession ? _source : _target;

        expect(await refusalOf(service.send(sourceSessionId: _source, targetSessionId: target)), code);
        expect(prompts.sends, isEmpty);
        expect(transcripts.saved, isEmpty);
      });
    }

    test("an empty source", () async {
      history.messages = [];

      expect(await refusalOf(send()), SendToSessionErrorCode.sourceEmpty);
      expect(prompts.sends, isEmpty);
    });

    test("a missing session, as not found", () async {
      sessions.byId.remove(_target);

      await expectLater(send(), throwsA(isA<PluginOperationException>().having((e) => e.isNotFound, "notFound", true)));
      expect(prompts.sends, isEmpty);
    });
  });

  test("a source that refuses the summary request is unavailable", () async {
    prompts.summaryFailure = StateError("plugin not routable");

    expect(await refusalOf(send()), SendToSessionErrorCode.sourceUnavailable);
    expect(transcripts.saved, isEmpty);
  });

  test("a source whose saved options its harness no longer offers says so", () async {
    prompts.summaryFailure = _staleOptions();

    expect(await refusalOf(send()), SendToSessionErrorCode.sourceOptionsUnavailable);
    expect(transcripts.saved, isEmpty);
  });

  test("a stop during the summary cancels the send", () async {
    prompts.onSummaryAccepted = (promptId) {
      events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
      // Archive's stop and the user's stop both announce themselves here.
      aborts.add(_source);
      events.add(const NormalizedStatusEvent(sessionId: _source, status: SessionStatus.idle()));
    };

    expect(await refusalOf(send()), SendToSessionErrorCode.summaryStopped);
    expect(transcripts.saved, isEmpty);
    expect(prompts.sends, hasLength(1));
  });

  test("a stop of another session does not cancel the send", () async {
    prompts.onSummaryAccepted = (promptId) {
      aborts.add(_target);
      events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
      events.add(const NormalizedStatusEvent(sessionId: _source, status: SessionStatus.idle()));
    };

    await send();

    expect(prompts.sends.last.sessionId, _target);
  });

  test("a second send racing the first is refused as busy", () async {
    final accepted = Completer<String>();
    prompts.onSummaryAccepted = (promptId) {
      // The harness reports the turn as running once it accepts the prompt.
      sessions.statuses[_source] = const SessionStatus.busy(since: null);
      accepted.complete(promptId);
    };

    final first = send();
    final second = send();
    final promptId = await accepted.future;

    expect(await refusalOf(second), SendToSessionErrorCode.sourceBusy);
    events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
    events.add(const NormalizedStatusEvent(sessionId: _source, status: SessionStatus.idle()));
    await first;
    expect(prompts.sends.where((send) => send.sessionId == _source), hasLength(1));
    expect(transcripts.saved, hasLength(1));
  });

  test("idle before the echo does not end the wait", () async {
    prompts.onSummaryAccepted = (promptId) {
      events.add(const NormalizedStatusEvent(sessionId: _source, status: SessionStatus.idle()));
      events.add(NormalizedMessageEvent(message: _echo(promptId: "prm_other")));
      events.add(const NormalizedStatusEvent(sessionId: _source, status: SessionStatus.idle()));
      events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
      events.add(const NormalizedStatusEvent(sessionId: _source, status: SessionStatus.idle()));
    };

    await send();

    expect(transcripts.saved, hasLength(1));
  });

  test("a session idle event also ends the summary turn", () async {
    prompts.onSummaryAccepted = (promptId) {
      events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
      events.add(const NormalizedOtherEvent(event: BridgeSseSessionIdle(sessionID: _source)));
    };

    await send();

    expect(transcripts.saved, hasLength(1));
  });

  test("a running source whose status read failed is unavailable", () async {
    sessions.unavailablePluginIds.add("claude");

    expect(await refusalOf(send()), SendToSessionErrorCode.sourceUnavailable);
    expect(prompts.sends, isEmpty);
  });

  test("a source whose backend is not running counts as idle", () async {
    sessions.unavailablePluginIds.add("claude");
    sessions.pluginsActive = false;
    finishSummaryTurn();

    await send();

    expect(transcripts.saved, hasLength(1));
  });

  test("an error message in the summary turn fails the send", () async {
    prompts.onSummaryAccepted = (promptId) {
      events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
      events.add(
        const NormalizedMessageEvent(
          message: Message.error(
            id: "turn-1",
            sessionID: _source,
            agent: null,
            modelID: null,
            providerID: null,
            errorName: "FixtureError",
            errorMessage: "fixture failure",
            time: null,
          ),
        ),
      );
      events.add(const NormalizedStatusEvent(sessionId: _source, status: SessionStatus.idle()));
    };

    expect(await refusalOf(send()), SendToSessionErrorCode.summaryFailed);
    expect(transcripts.saved, isEmpty);
  });

  test("bridge shutdown ends a summary wait as stopped", () async {
    prompts.onSummaryAccepted = (promptId) {
      events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
      service.beginShutdown();
    };

    expect(await refusalOf(send()), SendToSessionErrorCode.summaryStopped);
    expect(transcripts.saved, isEmpty);
  });

  test("a send that reaches the source after shutdown began sends nothing", () async {
    service.beginShutdown();

    expect(await refusalOf(send()), SendToSessionErrorCode.sourceUnavailable);
    expect(prompts.sends, isEmpty);
  });

  test("the echo id wins over a later message with the request's text", () async {
    finishSummaryTurn();
    history.repeatRequestTextLater = () => prompts.sends.first.text;

    await send();

    expect(prompts.sends.last.text, contains(_summary));
  });

  test("a replayed summary request is found by its text", () async {
    finishSummaryTurn();
    // A replay gives the request a new id, as ACP replays do.
    history.replayRequestText = () => prompts.sends.first.text;

    await send();

    expect(utf8.decode(transcripts.saved.single.bytes), contains(_transcriptLine));
    expect(prompts.sends.last.text, contains(_summary));
  });

  test("a reply to a prompt queued behind the summary stays out of it", () async {
    finishSummaryTurn();
    history.messages = [
      ...history.messages,
      _userMessage(id: "msg-5", text: "queued prompt"),
      _assistantMessage(id: "msg-6", text: "Fixture queued reply."),
    ];

    await send();

    expect(prompts.sends.last.text, isNot(contains("Fixture queued reply.")));
  });

  test("a session error during the summary fails the send", () async {
    prompts.onSummaryAccepted = (promptId) {
      events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
      events.add(const NormalizedOtherEvent(event: BridgeSseSessionError(sessionID: _source)));
    };

    expect(await refusalOf(send()), SendToSessionErrorCode.summaryFailed);
    expect(transcripts.saved, isEmpty);
  });

  test("a plugin stop that ends the turn fails the send", () async {
    prompts.onSummaryAccepted = (promptId) {
      events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
      events.add(
        const NormalizedTerminalHandoff(
          payload: NormalizedStatusEvent(sessionId: _source, status: SessionStatus.idle()),
        ),
      );
    };

    expect(await refusalOf(send()), SendToSessionErrorCode.summaryFailed);
  });

  test("a summary that never ends times out", () async {
    // The orchestrator waits 15 minutes; a short wait proves the same path.
    service = buildService(summaryTimeout: const Duration(milliseconds: 20));
    prompts.onSummaryAccepted = (promptId) {
      events.add(NormalizedMessageEvent(message: _echo(promptId: promptId)));
    };

    expect(await refusalOf(send()), SendToSessionErrorCode.summaryTimedOut);
    expect(transcripts.saved, isEmpty);
  });

  test("a turn without summary text is missing its summary", () async {
    finishSummaryTurn();
    history.messages = [
      ...history.messages.take(3),
      _assistantMessage(id: "msg-4", text: "  "),
    ];

    expect(await refusalOf(send()), SendToSessionErrorCode.summaryMissing);
    expect(transcripts.saved, isEmpty);
  });

  test("history without the summary request is missing its summary", () async {
    finishSummaryTurn();
    history.messages = history.messages.take(2).toList();

    expect(await refusalOf(send()), SendToSessionErrorCode.summaryMissing);
  });

  test("a failed refresh still reads the stored history", () async {
    finishSummaryTurn();
    history.backfillFailure = StateError("harness cannot replay");

    await send();

    expect(transcripts.saved, hasLength(1));
  });

  test("a failed transcript write fails the send before the target is prompted", () async {
    finishSummaryTurn();
    transcripts.failure = const FormatException("disk full");

    expect(await refusalOf(send()), SendToSessionErrorCode.transcriptUnavailable);
    expect(prompts.sends.where((send) => send.sessionId == _target), isEmpty);
  });

  test("a target refusal carries the harness's reason", () async {
    finishSummaryTurn();
    prompts.targetFailure = SessionPromptRefusedException(
      cause: const PluginRefusalException(
        operation: "sendPrompt",
        userFacingReason: "The target is read-only.",
        cause: null,
      ),
      causeStackTrace: StackTrace.current,
    );

    try {
      await send();
      fail("the send succeeded");
    } on SessionSendRejectedException catch (error) {
      expect(error.code, SendToSessionErrorCode.targetRefused);
      expect(error.userFacingReason, "The target is read-only.");
      expect(error.cause, isA<SessionPromptRefusedException>());
    }
  });

  test("a target whose saved options its harness no longer offers says so", () async {
    finishSummaryTurn();
    prompts.targetFailure = _staleOptions();

    expect(await refusalOf(send()), SendToSessionErrorCode.targetOptionsUnavailable);
  });

  test("no prompt, summary or transcript text reaches the log", () async {
    final logs = captureLogOutput();
    final level = Log.level;
    Log.level = LogLevel.verbose;
    addTearDown(() => Log.level = level);
    finishSummaryTurn();

    await send();
    prompts.targetFailure = StateError("target down");
    expect(await refusalOf(send()), SendToSessionErrorCode.targetRefused);

    expect(logs.text, contains(_source));
    for (final text in [_summary, _transcriptLine, "handoff summary", "This is a handoff"]) {
      expect(logs.text, isNot(contains(text)));
    }
  });
}

Message _echo({required String promptId}) => Message.user(
  id: _requestMessageId,
  sessionID: _source,
  agent: null,
  time: null,
  promptId: promptId,
  invocation: null,
  handoff: null,
);

MessageWithParts _userMessage({required String id, required String text, MessageHandoff? handoff}) => MessageWithParts(
  info: Message.user(
    id: id,
    sessionID: _source,
    agent: null,
    time: null,
    promptId: null,
    invocation: null,
    handoff: handoff,
  ),
  parts: [MessagePart.text(id: "$id-text", sessionID: _source, messageID: id, text: text)],
);

MessageWithParts _assistantMessage({required String id, required String text}) => MessageWithParts(
  info: Message.assistant(
    id: id,
    sessionID: _source,
    agent: null,
    modelID: null,
    providerID: null,
    time: null,
  ),
  parts: [MessagePart.text(id: "$id-text", sessionID: _source, messageID: id, text: text)],
);

Session _session({
  required String id,
  required String pluginId,
  required String title,
  required SessionPromptDefaults? promptDefaults,
}) => Session(
  id: id,
  pluginId: pluginId,
  projectID: "/fixture",
  directory: "/fixture/$id",
  parentID: null,
  title: title,
  time: const SessionTime(created: 1, updated: 2, archived: null),
  promptDefaults: promptDefaults,
  branchName: null,
  lastUserActivityAt: null,
  autoContinuation: null,
  approvalOverride: null,
  pinOrder: null,
  scheduledTask: null,
  interruption: null,
  forkedFrom: null,
);

final class _Sessions() implements SessionRepository {
  final Map<String, Session> byId = {
    _source: _session(
      id: _source,
      pluginId: "claude",
      title: "Source title",
      promptDefaults: const SessionPromptDefaults(
        agent: "plan",
        model: AgentModel(modelID: "opus", providerID: "anthropic", variant: "high"),
        fastMode: true,
      ),
    ),
    _target: _session(id: _target, pluginId: "codex", title: "Target title", promptDefaults: null),
  };
  final Map<String, SessionStatus> statuses = {};
  final List<String> unavailablePluginIds = [];
  bool pluginsActive = true;

  /// Prompt ids whose handoff stamp was marked as not sent.
  final List<String> notSentPrompts = [];

  @override
  void markHandoffNotSent({required String sessionId, required String promptId}) {
    expect(sessionId, _source);
    notSentPrompts.add(promptId);
  }

  void reparent({required String sessionId}) {
    final session = byId[sessionId];
    if (session == null) return;
    byId[sessionId] = session.copyWith(parentID: "parent");
  }

  void archive({required String sessionId}) {
    final session = byId[sessionId];
    if (session == null) return;
    byId[sessionId] = session.copyWith(time: const SessionTime(created: 1, updated: 2, archived: 3));
  }

  @override
  Future<SessionStatusResponse> getSessionStatuses() async =>
      SessionStatusResponse(statuses: Map.of(statuses), unavailablePluginIds: List.of(unavailablePluginIds));

  @override
  bool isPluginActive({required String pluginId}) => pluginsActive;

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async => (rootSessionId: sessionId, pluginId: byId[sessionId]?.pluginId ?? "missing");

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class const _Views({required final _Sessions _sessions}) implements SessionViewService {
  @override
  Future<Session> get({required String sessionId}) async =>
      _sessions.byId[sessionId] ??
      (throw PluginOperationException.notFound(operation: "getSession", message: "session $sessionId was not found"));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class const _Permissions() implements PermissionRepository {
  @override
  Future<List<PendingPermission>> getPendingPermissions({required String sessionId}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Questions() implements QuestionRepository {
  bool pending = false;

  @override
  Future<List<PendingQuestion>> getPendingQuestions({required String sessionId}) async => [
    if (pending) PendingQuestion(id: "question", sessionID: sessionId, displaySessionId: null, questions: const []),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Send = ({
  String sessionId,
  String? promptId,
  bool reserved,
  String text,
  String? agent,
  PromptModel? model,
  SessionVariant? variant,
  bool fastMode,
  MessageHandoff? handoff,
});

StaleSessionPromptOptionsException _staleOptions() => StaleSessionPromptOptionsException(
  cause: const PluginStaleOptionsException(operation: "sendPrompt", message: "no longer offers the selected model"),
  causeStackTrace: StackTrace.current,
);

final class _Prompts() implements SessionPromptService {
  final List<_Send> sends = [];
  Object? summaryFailure;
  Object? targetFailure;

  /// Runs after the source accepts the summary request, with its prompt id.
  void Function(String promptId)? onSummaryAccepted;

  @override
  Future<void> sendPromptAlreadyReserved({
    required String sessionId,
    required String promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required CommandSource? commandSource,
    required MessageHandoff? handoff,
  }) async {
    if (summaryFailure case final failure?) throw failure;
    sends.add(
      _record(
        sessionId: sessionId,
        promptId: promptId,
        reserved: true,
        parts: parts,
        variant: variant,
        fastMode: fastMode,
        agent: agent,
        model: model,
        handoff: handoff,
      ),
    );
    onSummaryAccepted?.call(promptId);
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required String? promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required CommandSource? commandSource,
    required MessageHandoff? handoff,
  }) async {
    if (targetFailure case final failure?) throw failure;
    sends.add(
      _record(
        sessionId: sessionId,
        promptId: promptId,
        reserved: false,
        parts: parts,
        variant: variant,
        fastMode: fastMode,
        agent: agent,
        model: model,
        handoff: handoff,
      ),
    );
  }

  static _Send _record({
    required String sessionId,
    required String? promptId,
    required bool reserved,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required MessageHandoff? handoff,
  }) => (
    sessionId: sessionId,
    promptId: promptId,
    reserved: reserved,
    text: [
      for (final part in parts)
        if (part case PromptPartText(:final text)) text,
    ].join(),
    agent: agent,
    model: model,
    variant: variant,
    fastMode: fastMode,
    handoff: handoff,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Events() implements SessionEventDispatcher {
  final StreamController<NormalizedSourcedBridgeEvent> _controller = StreamController.broadcast();

  void add(NormalizedBridgeEvent event) => _controller.add((
    pluginId: "claude",
    generation: 1,
    event: event,
    allowDuringStop: false,
    terminalHandoffConsumed: null,
  ));

  Future<void> close() => _controller.close();

  @override
  Stream<NormalizedSourcedBridgeEvent> get events => _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Aborts() implements SessionAbortService {
  final StreamController<String> _controller = StreamController.broadcast(sync: true);

  void add(String sessionId) => _controller.add(sessionId);

  Future<void> close() => _controller.close();

  @override
  Stream<String> get abortStartedSessions => _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _History() implements ChatHistoryService {
  List<MessageWithParts> messages = [];
  final List<String> backfilled = [];
  Object? backfillFailure;

  /// When set, a backfill replaces the summary request with a replayed copy
  /// under another id, carrying this text.
  String Function()? replayRequestText;

  /// When set, a backfill appends a later user message carrying this text and
  /// an unrelated reply.
  String Function()? repeatRequestTextLater;

  /// Message ids whose stored handoff was marked as not sent.
  final List<String> notSentMessages = [];

  @override
  Future<void> markHandoffNotSent({required String sessionId, required String messageId}) async {
    expect(sessionId, _source);
    notSentMessages.add(messageId);
  }

  @override
  Future<void> backfillSession({required String sessionId}) async {
    if (backfillFailure case final failure?) throw failure;
    backfilled.add(sessionId);
    if (repeatRequestTextLater case final text?) {
      messages = [
        ...messages,
        _userMessage(id: "later-user", text: text()),
        _assistantMessage(id: "later-reply", text: "Fixture later reply."),
      ];
    }
    if (replayRequestText case final text?) {
      messages = [
        for (final message in messages)
          message.info.id == _requestMessageId ? _userMessage(id: "replayed-user", text: text()) : message,
      ];
    }
  }

  @override
  Future<SessionMessagesPage> getSessionMessages({
    required String sessionId,
    required HistoryWindow window,
    required MessageAttachmentDelivery attachmentDelivery,
    required ToolOutputDelivery toolOutputDelivery,
    required bool storedOnly,
    required bool backgroundRefresh,
  }) async => (
    messages: switch (window) {
      HistoryWindowAll() => messages,
      HistoryWindowNewest(:final limit) => messages.reversed.take(limit).toList().reversed.toList(),
      HistoryWindowThrough() => throw UnimplementedError(),
    },
    nextCursor: null,
    replayedPromptDefaults: null,
    awaitingHarnessSync: false,
    userMessagesBefore: 0,
    cannotContinueMessage: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Saved = ({String sessionId, List<int> bytes, String filename});

final class _Transcripts() implements PromptUploadRepository {
  final List<_Saved> saved = [];
  Object? failure;

  String pathFor(_Saved file) => "/fixture-home/.sesori/transcripts/${file.sessionId}/2026-11-15-abc/${file.filename}";

  @override
  Future<String> save({required String sessionId, required List<int> bytes, required String filename}) async {
    if (failure case final failure?) throw failure;
    final file = (sessionId: sessionId, bytes: bytes, filename: filename);
    saved.add(file);
    return pathFor(file);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class const _Plugins() implements PluginLifecycleService {
  @override
  List<PluginMetadata> get selectableMetadataSnapshot => const [
    PluginMetadata(
      id: "claude",
      displayName: "Claude Code",
      isDefault: true,
      state: PluginLifecycleState.ready,
      actionHint: null,
      failureBlock: null,
      mcpScopes: null,
      failureReason: null,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
