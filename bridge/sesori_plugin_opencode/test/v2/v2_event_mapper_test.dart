import "package:opencode_plugin/src/v2/models/openapi/session_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_info.g.dart";
import "package:opencode_plugin/src/v2/models/v2_agent_names.dart";
import "package:opencode_plugin/src/v2/models/v2_event.g.dart";
import "package:opencode_plugin/src/v2/models/v2_execution_interrupt_reason.dart";
import "package:opencode_plugin/src/v2/repositories/v2_message_mapper.dart";
import "package:opencode_plugin/src/v2/repositories/v2_model_mapper.dart";
import "package:opencode_plugin/src/v2/sse/v2_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/v2_fixtures.dart";

const names = V2AgentNames(namesById: {"build": "Build", "explore": "Explore"});
const models = V2ModelMapper(pluginId: "fixture-plugin");
const messages = V2MessageMapper();
const mapper = V2EventMapper(modelMapper: models, messageMapper: messages);

V2EventEnvelope frame({required String type, required Map<String, dynamic> data}) => V2EventEnvelope.fromJson(
  <String, dynamic>{
    "id": "evt_notice",
    "created": 42,
    "type": type,
    "location": <String, String>{"directory": "/fixture/project"},
    "data": data,
  },
);

PluginMessageWithParts assistant({required bool retry}) => messages.mapMessage(
  sessionId: "s",
  agentNames: names,
  message: SessionMessageInfo.fromJson(<String, dynamic>{
    "id": "m",
    "type": "assistant",
    "agent": "build",
    "model": const <String, dynamic>{"id": "model", "providerID": "provider"},
    "time": const <String, int>{"created": 1, "completed": 2},
    "content": const <Object>[
      <String, dynamic>{"type": "text", "text": "Later text must not be replayed"},
      <String, dynamic>{
        "type": "tool",
        "id": "tool",
        "name": "shell",
        "time": <String, int>{"created": 1},
        "state": <String, dynamic>{
          "status": "completed",
          "input": <String, dynamic>{"command": "pwd"},
          "content": <Object>[
            <String, dynamic>{"type": "text", "text": "Fixture output"},
          ],
        },
      },
    ],
    if (retry)
      "retry": <String, dynamic>{
        "attempt": 2,
        "at": 90,
        "error": <String, dynamic>{"type": "fixture", "message": "Retry fixture"},
      },
  }),
)!;

void main() {
  test("maps execution status without treating shutdown or an unknown reason as idle", () {
    expect(
      (mapper
                  .map(
                    envelope: frame(type: "session.execution.started", data: {"sessionID": "s"}),
                  )
                  .single
              as BridgeSseSessionStatus)
          .status,
      const PluginSessionStatus.busy(),
    );
    for (final reason in ["user", "superseded", "inactivity", "shutdown", "future-reason"]) {
      final event = frame(type: "session.execution.interrupted", data: {"sessionID": "s", "reason": reason});
      final result = mapper.map(envelope: event);
      if (reason == "shutdown" || reason == "future-reason") {
        expect(result, isEmpty);
      } else {
        expect((result.single as BridgeSseSessionStatus).status, const PluginSessionStatus.idle());
      }
      if (reason == "future-reason") {
        expect((event.data as V2SessionExecutionInterrupted).reason, V2ExecutionInterruptReason.unknown);
      }
    }
    final failed = mapper.map(
      envelope: frame(
        type: "session.execution.failed",
        data: {
          "sessionID": "s",
          "error": {"type": "fixture", "message": "Native failure", "status": 503},
        },
      ),
    );
    expect((failed.first as BridgeSseSessionStatus).status, const PluginSessionStatus.idle());
    expect(failed.whereType<BridgeSseTuiToastShow>().single.message, "Native failure");
  });

  for (final kind in ["text", "reasoning"]) {
    test("$kind start, delta and end retain the transcript ordinal", () {
      final base = <String, dynamic>{"sessionID": "s", "assistantMessageID": "m", "ordinal": 2};
      final start =
          mapper
                  .map(
                    envelope: frame(type: "session.$kind.started", data: base),
                  )
                  .single
              as BridgeSseMessagePartUpdated;
      final delta =
          mapper
                  .map(
                    envelope: frame(type: "session.$kind.delta", data: {...base, "delta": "Fixture"}),
                  )
                  .single
              as BridgeSseMessagePartDelta;
      final end =
          mapper
                  .map(
                    envelope: frame(type: "session.$kind.ended", data: {...base, "text": "Fixture"}),
                  )
                  .single
              as BridgeSseMessagePartUpdated;
      expect(start.part.id, "m:2");
      expect(delta.partID, start.part.id);
      expect(delta.field, "text");
      expect(end.part.id, start.part.id);
      expect(end.part.text, "Fixture");
      expect(end.part, kind == "text" ? isA<PluginMessagePartText>() : isA<PluginMessagePartReasoning>());
    });
  }

  test("tool updates retain the native ID and never replay other snapshot parts", () {
    final start =
        mapper
                .map(
                  envelope: frame(
                    type: "session.tool.input.started",
                    data: {
                      "sessionID": "s",
                      "assistantMessageID": "m",
                      "id": "tool",
                      "name": "shell",
                    },
                  ),
                )
                .single
            as BridgeSseMessagePartUpdated;
    expect(start.part.id, "tool");
    expect(start.part.asTool.state.status, PluginToolStatus.pending);
    expect(
      mapper.map(
        envelope: frame(
          type: "session.tool.input.delta",
          data: {
            "sessionID": "s",
            "assistantMessageID": "m",
            "id": "tool",
            "delta": '{"command":',
          },
        ),
      ),
      isEmpty,
    );
    final result = mapper.mapToolSnapshot(toolId: "tool", message: assistant(retry: false));
    final part = (result.single as BridgeSseMessagePartUpdated).part.asTool;
    expect(part.id, start.part.id);
    expect(part.state.shellCommand, "pwd");
    expect(part.state.output, "Fixture output");
    expect(part.state.status, PluginToolStatus.completed);
  });

  test("retry uses a stable part and is cleared by a new step without erasing text", () {
    final retry = mapper.map(
      envelope: frame(
        type: "session.retry.scheduled",
        data: {
          "sessionID": "s",
          "assistantMessageID": "m",
          "attempt": 2,
          "at": 90,
          "error": {"type": "fixture", "message": "Retry fixture"},
        },
      ),
    );
    expect(
      (retry.first as BridgeSseSessionStatus).status,
      const PluginSessionStatus.retry(attempt: 2, message: "Retry fixture", next: 90),
    );
    expect((retry.last as BridgeSseMessagePartUpdated).part.id, "m:retry");
    final step =
        frame(
              type: "session.step.started",
              data: {
                "sessionID": "s",
                "assistantMessageID": "m",
                "agent": "build",
                "started": 100,
                "model": {"id": "model", "providerID": "provider", "variant": "high"},
              },
            ).data
            as V2SessionStepStarted;
    final result = mapper.mapAssistantStarted(event: step, agentNames: names);
    final info = (result.first as BridgeSseMessageUpdated).info as PluginMessageAssistant;
    expect(info.agent, "Build");
    expect(info.variant, "high");
    expect(info.time!.created, 100);
    expect((result.last as BridgeSseMessagePartRemoved).partID, "m:retry");
    expect(V2EventMapper.status(event: step)!.status, const PluginSessionStatus.busy());
  });

  test("terminal assistant hydration updates only the header and authoritative retry state", () {
    for (final retry in [false, true]) {
      final result = mapper.mapAssistantSnapshot(message: assistant(retry: retry));
      expect(result, hasLength(2));
      expect((result.first as BridgeSseMessageUpdated).info.time!.completed, 2);
      if (retry) {
        expect((result.last as BridgeSseMessagePartUpdated).part.id, "m:retry");
      } else {
        expect((result.last as BridgeSseMessagePartRemoved).partID, "m:retry");
      }
    }
  });

  test("native notices match REST identities, attribution and synthetic descriptions", () {
    final result = mapper.mapNotice(
      envelope: frame(
        type: "session.agent.selected",
        data: {
          "sessionID": "s",
          "agent": "explore",
          "previous": "build",
        },
      ),
      agentNames: names,
    );
    final info = (result.first as BridgeSseMessageUpdated).info as PluginMessageAssistant;
    expect(info.id, "msg_notice");
    expect(info.sender, PluginMessageSender.system);
    expect(info.time!.completed, 42);
    expect((result.last as BridgeSseMessagePartUpdated).part.id, "msg_notice:0");
    expect((result.last as BridgeSseMessagePartUpdated).part.agentName, "Explore");
    final synthetic = mapper.mapNotice(
      envelope: frame(
        type: "session.synthetic",
        data: {
          "sessionID": "s",
          "text": "Internal fixture",
          "description": "Visible fixture",
        },
      ),
      agentNames: names,
    );
    expect((synthetic.last as BridgeSseMessagePartUpdated).part.text, "Visible fixture");
  });

  test("recognizes inbox lifecycle without inventing an enqueued transcript message", () {
    for (final type in ["enqueued", "delivered", "cancelled", "delivery.changed"]) {
      final event = frame(type: "session.inbox.$type", data: {"sessionID": "s", "inboxID": "msg_input"});
      expect(event.data, isA<V2SessionEventData>());
      expect(mapper.map(envelope: event), isEmpty);
    }
    final delivered = messages.mapMessage(
      sessionId: "s",
      agentNames: names,
      message: SessionMessageInfo.fromJson(
        const <String, dynamic>{
          "id": "msg_input",
          "type": "user",
          "text": "Fixture",
          "time": <String, int>{"created": 50},
        },
      ),
    )!;
    final result = mapper.mapMessageSnapshot(message: delivered);
    expect((result.first as BridgeSseMessageUpdated).info.id, "msg_input");
    expect((result.last as BridgeSseMessagePartUpdated).part.id, "msg_input:0");
  });

  test("completed compaction uses its native message ID rather than the completion event", () {
    final message = messages.mapMessage(
      sessionId: "s",
      agentNames: names,
      message: SessionMessageInfo.fromJson(
        const <String, dynamic>{
          "id": "msg_compaction_started",
          "type": "compaction",
          "status": "completed",
          "reason": "manual",
          "summary": "Fixture summary",
          "recent": "",
          "time": <String, int>{"created": 1},
        },
      ),
    )!;
    final result = mapper.mapMessageSnapshot(message: message);
    expect((result.first as BridgeSseMessageUpdated).info.id, "msg_compaction_started");
    expect((result[1] as BridgeSseMessagePartUpdated).part.id, "msg_compaction_started:0");
    expect(result.last, isA<BridgeSseSessionCompacted>());
  });

  test("pending inputs reuse catalog mapping and retain root display attribution", () {
    final permission =
        mapper
                .mapInput(
                  event: frame(
                    type: "permission.asked",
                    data: {
                      "sessionID": "child",
                      "id": "permission",
                      "action": "shell",
                      "resources": ["pwd"],
                      "message": "Approve fixture",
                    },
                  ).data,
                  displaySessionId: "root",
                )
                .single
            as BridgeSsePermissionAsked;
    expect(permission.description, "Approve fixture");
    expect(permission.sessionID, "child");
    expect(permission.displaySessionId, "root");
    final reply =
        mapper
                .mapInput(
                  event: frame(
                    type: "permission.replied",
                    data: {
                      "sessionID": "child",
                      "requestID": "permission",
                      "reply": "once",
                    },
                  ).data,
                  displaySessionId: "root",
                )
                .single
            as BridgeSsePermissionReplied;
    expect(reply.requestID, "permission");
    expect(reply.reply, "once");
    final form =
        mapper
                .mapInput(
                  event: frame(
                    type: "form.created",
                    data: {
                      "form": {
                        "id": "form",
                        "sessionID": "child",
                        "fields": [
                          {
                            "type": "string",
                            "key": "choice",
                            "options": [
                              {"value": "native", "label": "Visible"},
                            ],
                          },
                        ],
                      },
                    },
                  ).data,
                  displaySessionId: "root",
                )
                .single
            as BridgeSseQuestionAsked;
    expect(form.questions.single.options.single.label, "Visible");
    expect(form.displaySessionId, "root");
    expect(
      mapper
          .mapInput(
            event: frame(
              type: "form.replied",
              data: {
                "id": "form",
                "sessionID": "child",
                "answer": <String, dynamic>{},
              },
            ).data,
            displaySessionId: "root",
          )
          .single,
      isA<BridgeSseQuestionReplied>(),
    );
    expect(
      mapper
          .mapInput(
            event: frame(
              type: "form.cancelled",
              data: {
                "id": "form",
                "sessionID": "child",
              },
            ).data,
            displaySessionId: "root",
          )
          .single,
      isA<BridgeSseQuestionRejected>(),
    );
  });

  test("session mutations serialize authoritative neutral session details", () {
    final session = models.mapSessionDetails(
      session: SessionInfo.fromJson(v2SessionFixture),
      projectId: "/fixture/project",
      agentNames: names,
    );
    final data = <String, dynamic>{
      "sessionID": session.id,
      "projectID": "native-project",
      "location": <String, String>{"directory": "/fixture/project"},
      "slug": "fixture",
      "version": "2.0.16",
      "title": "Fixture",
    };
    final created =
        mapper.mapSession(
              event: frame(type: "session.created", data: data).data,
              session: session,
            )!
            as BridgeSseSessionCreated;
    expect(created.info["projectID"], "/fixture/project");
    expect(created.info["pluginId"], "fixture-plugin");
    final renamed =
        mapper.mapSession(
              event: frame(type: "session.renamed", data: data).data,
              session: session,
            )!
            as BridgeSseSessionUpdated;
    expect(renamed.titleChanged, isTrue);
    expect(
      mapper.mapSession(
        event: frame(type: "session.deleted", data: data).data,
        session: session,
      ),
      isA<BridgeSseSessionDeleted>(),
    );
  });
}
