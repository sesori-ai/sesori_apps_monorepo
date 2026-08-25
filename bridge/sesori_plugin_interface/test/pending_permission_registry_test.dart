import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class const _Payload({required final String value});

class _Registry({
  required super.emit,
  required super.resolvePermission,
  required super.resolveQuestion,
  required super.rejectQuestion,
  required super.cancelPending,
}) extends PendingPermissionRegistry<String, _Payload> {
  this : super(logContext: "[test]");

  final List<String> requests = [];

  @override
  void handleRequest(String request) => requests.add(request);

  String addPermission({required String payload, required String sessionId}) => registerPendingPermission(
    payload: _Payload(value: payload),
    sessionId: sessionId,
    displaySessionId: sessionId,
    tool: "tool-$payload",
    description: "description-$payload",
    allowAlways: true,
  );

  String addQuestion({required String payload, required String sessionId}) => registerPendingQuestion(
    payload: _Payload(value: payload),
    sessionId: sessionId,
    displaySessionId: sessionId,
    questions: const [
      PluginQuestionInfo(question: "Proceed?", header: "Confirm", options: [], multiple: false, custom: true),
    ],
  );
}

void main() {
  _Registry registry({
    required List<BridgeSseEvent> events,
    PendingPermissionResolver<_Payload>? resolvePermission,
    PendingQuestionResolver<_Payload>? resolveQuestion,
    PendingQuestionRejecter<_Payload>? rejectQuestion,
    PendingInputCanceller<_Payload>? cancelPending,
  }) => _Registry(
    emit: events.add,
    resolvePermission: resolvePermission ?? ({required payload, required reply}) {},
    resolveQuestion: resolveQuestion ?? ({required payload, required answers}) => PendingQuestionReplyOutcome.replied,
    rejectQuestion: rejectQuestion ?? ({required payload}) {},
    cancelPending: cancelPending ?? ({required payload, required reason}) {},
  );

  test("registers exact snapshots and settles replies with clearing events", () {
    final events = <BridgeSseEvent>[];
    final permissions = <(String, PluginPermissionReply)>[];
    final questions = <String>[];
    final subject = registry(
      events: events,
      resolvePermission: ({required payload, required reply}) => permissions.add((payload.value, reply)),
      resolveQuestion: ({required payload, required answers}) {
        questions.add(payload.value);
        return PendingQuestionReplyOutcome.rejected;
      },
    );

    final permissionId = subject.addPermission(payload: "permission", sessionId: "s1");
    final questionId = subject.addQuestion(payload: "question", sessionId: "s1");

    expect([permissionId, questionId], ["br-1", "br-2"]);
    expect(subject.pendingPermissionsForSession(sessionId: "s1").single.tool, "tool-permission");
    expect(subject.pendingForSession(sessionId: "s1").single.id, questionId);
    expect(subject.pendingSessionIds, {"s1"});

    expect(
      subject.replyPermission(requestId: permissionId, reply: PluginPermissionReply.once),
      isTrue,
    );
    expect(
      subject.replyQuestion(
        requestId: questionId,
        answers: const [
          ["yes"],
        ],
      ),
      isTrue,
    );

    expect(permissions, [("permission", PluginPermissionReply.once)]);
    expect(questions, ["question"]);
    expect(events.whereType<BridgeSsePermissionReplied>(), hasLength(1));
    expect(events.whereType<BridgeSseQuestionRejected>(), hasLength(1));
    expect(subject.hasAnyPendingInput, isFalse);
  });

  test("a kind-mismatched reply leaves the entry pending and answerable", () {
    final events = <BridgeSseEvent>[];
    final subject = registry(events: events);
    final permissionId = subject.addPermission(payload: "permission", sessionId: "s1");
    final questionId = subject.addQuestion(payload: "question", sessionId: "s1");
    events.clear();

    expect(subject.replyQuestion(requestId: permissionId, answers: const []), isFalse);
    expect(subject.rejectQuestion(requestId: permissionId), isFalse);
    expect(subject.replyPermission(requestId: questionId, reply: PluginPermissionReply.once), isFalse);
    expect(events, isEmpty);

    expect(subject.replyPermission(requestId: permissionId, reply: PluginPermissionReply.once), isTrue);
    expect(subject.rejectQuestion(requestId: questionId), isTrue);
    expect(subject.hasAnyPendingInput, isFalse);
  });

  test("session cancellation logs one backend failure and settles every entry", () async {
    final events = <BridgeSseEvent>[];
    final cancelled = <String>[];
    final subject = registry(
      events: events,
      cancelPending: ({required payload, required reason}) {
        cancelled.add(payload.value);
        if (payload.value == "bad") throw StateError("backend failed");
      },
    );
    subject.addPermission(payload: "bad", sessionId: "s1");
    subject.addQuestion(payload: "good", sessionId: "s1");
    subject.addQuestion(payload: "other", sessionId: "s2");
    events.clear();

    final stderrLines = <String>[];
    await IOOverrides.runZoned(
      () async => subject.cancelForSession(sessionId: "s1"),
      stderr: () => CapturingStdout(lines: stderrLines),
    );

    expect(cancelled, ["bad", "good"]);
    expect(events, [isA<BridgeSsePermissionReplied>(), isA<BridgeSseQuestionRejected>()]);
    expect(subject.pendingForSession(sessionId: "s2"), hasLength(1));
    expect(stderrLines.join("\n"), contains("[test] failed to resolve cancelled pending input"));
  });

  test("dispose settles pending input after subscription cancellation fails", () async {
    final events = <BridgeSseEvent>[];
    final cancelled = <String>[];
    final subject = registry(
      events: events,
      cancelPending: ({required payload, required reason}) => cancelled.add(payload.value),
    );
    final stream = StreamController<String>(
      onCancel: () => throw StateError("cancel failed"),
    );
    subject.attach(stream: stream.stream);
    subject.addPermission(payload: "permission", sessionId: "s1");
    events.clear();

    final stderrLines = <String>[];
    await IOOverrides.runZoned(
      subject.dispose,
      stderr: () => CapturingStdout(lines: stderrLines),
    );

    expect(cancelled, ["permission"]);
    expect(events.single, isA<BridgeSsePermissionReplied>());
    expect(subject.hasAnyPendingInput, isFalse);
    expect(stderrLines.join("\n"), contains("[test] failed to cancel pending-input subscription"));
    await stream.close();
  });
}
