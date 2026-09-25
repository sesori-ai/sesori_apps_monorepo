import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/open_code_raw_http_client.dart";
import "package:opencode_plugin/src/v2/api/opencode_v2_api.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_answer.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_reply.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/location_public_ref.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/model_ref.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/permission_reply.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_user.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/worktree_remove_input.g.dart";
import "package:opencode_plugin/src/v2/models/v2_decode_exception.dart";
import "package:opencode_plugin/src/v2/models/v2_request_bodies.dart";
import "package:test/test.dart";

import "support/v2_fixtures.dart";

OpenCodeV2Api makeApi({required Future<http.Response> Function(http.Request) handler}) {
  final client = MockClient(handler);
  addTearDown(client.close);
  return OpenCodeV2Api(
    client: OpenCodeRawHttpClient(serverURL: "http://localhost:4096", password: "fixture", client: client),
  );
}

void main() {
  test("reads direct server/location responses with shared authentication", () async {
    final api = makeApi(
      handler: (request) async {
        expect(request.headers["Authorization"], "Basic ${base64.encode(utf8.encode("opencode:fixture"))}");
        final body = switch (request.url.path) {
          "/api/info" => <String, dynamic>{
            "version": "2.0.16",
            "pid": 42,
            "urls": <String>[],
            "paths": <String, dynamic>{"tmp": "/fixture/tmp"},
          },
          "/api/location" => v2LocationFixture,
          _ => throw StateError("Unexpected test route"),
        };
        if (request.url.path == "/api/location") {
          expect(request.url.queryParameters, <String, String>{"location[directory]": "/fixture/project"});
        }
        return http.Response(jsonEncode(body), 200);
      },
    );
    expect((await api.getServerInfo()).version, "2.0.16");
    expect((await api.getLocation(directory: "/fixture/project")).project.id, "project-fixture");
  });

  test("follows session cursors while retaining filters and ordering", () async {
    var calls = 0;
    final api = makeApi(
      handler: (request) async {
        calls++;
        expect(request.url.path, "/api/session");
        expect(request.url.queryParameters["directory"], "/fixture/project");
        expect(request.url.queryParameters["parentID"], "parent-fixture");
        expect(request.url.queryParameters["order"], "asc");
        expect(request.url.queryParameters["cursor"], calls == 1 ? null : "cursor-2");
        return http.Response(
          jsonEncode(<String, dynamic>{
            "data": <Object>[
              <String, dynamic>{...v2SessionFixture, "id": "session-$calls"},
            ],
            "cursor": <String, dynamic>{"next": calls == 1 ? "cursor-2" : null},
          }),
          200,
        );
      },
    );
    final sessions = await api.listSessions(directory: "/fixture/project", parentId: "parent-fixture");
    expect(sessions.map((session) => session.id), <String>["session-1", "session-2"]);
    expect(calls, 2);
  });

  test("follows message cursors and decodes message variants", () async {
    var calls = 0;
    final api = makeApi(
      handler: (request) async {
        calls++;
        expect(request.url.path, "/api/session/session-fixture/message");
        expect(request.url.queryParameters["cursor"], calls == 1 ? null : "next");
        expect(request.url.queryParameters["order"], "asc");
        return http.Response(
          jsonEncode(<String, dynamic>{
            "data": <Object>[
              <String, dynamic>{
                "id": "message-$calls",
                "type": "user",
                "text": "fixture",
                "time": <String, int>{"created": calls},
              },
            ],
            "cursor": <String, dynamic>{"next": calls == 1 ? "next" : null},
          }),
          200,
        );
      },
    );
    final messages = await api.listMessages(sessionId: "session-fixture");
    expect(messages.cast<SessionMessageUser>().map((message) => message.id), <String>["message-1", "message-2"]);
    expect(calls, 2);
  });

  test("decodes data envelopes, active maps and nullable defaults", () async {
    final api = makeApi(
      handler: (request) async {
        final Object? data = switch (request.url.path) {
          "/api/session/active" => <String, dynamic>{
            "session-fixture": <String, dynamic>{"type": "running"},
          },
          "/api/session/session-fixture" => v2SessionFixture,
          "/api/model/default" => null,
          _ => throw StateError("Unexpected test route"),
        };
        return http.Response(jsonEncode(<String, dynamic>{"location": v2LocationFixture, "data": data}), 200);
      },
    );
    expect((await api.getActiveSessions()).keys, <String>["session-fixture"]);
    expect((await api.getSession(sessionId: "session-fixture")).id, "session-fixture");
    expect(await api.getDefaultModel(directory: "/fixture/project"), isNull);
  });

  for (final entry in <({String path, Future<Object> Function(OpenCodeV2Api) invoke})>[
    (path: "/api/agent", invoke: (api) => api.listAgents(directory: "/fixture/project")),
    (path: "/api/model", invoke: (api) => api.listModels(directory: "/fixture/project")),
    (path: "/api/provider", invoke: (api) => api.listProviders(directory: "/fixture/project")),
    (path: "/api/command", invoke: (api) => api.listCommands(directory: "/fixture/project")),
    (path: "/api/permission/request", invoke: (api) => api.listPermissions(directory: "/fixture/project")),
    (path: "/api/form", invoke: (api) => api.listForms(directory: "/fixture/project")),
  ]) {
    test("reads location-scoped ${entry.path}", () async {
      final api = makeApi(
        handler: (request) async {
          expect(request.url.path, entry.path);
          expect(request.url.queryParameters, <String, String>{"location[directory]": "/fixture/project"});
          return http.Response(jsonEncode(<String, dynamic>{"location": v2LocationFixture, "data": <Object>[]}), 200);
        },
      );
      expect(await entry.invoke(api), isEmpty);
    });
  }

  test("writes typed creation bodies and unwraps the result", () async {
    final api = makeApi(
      handler: (request) async {
        expect(request.method, "POST");
        expect(request.url.path, "/api/session");
        expect(jsonDecode(request.body), <String, dynamic>{
          "location": <String, dynamic>{"directory": "/fixture/project"},
        });
        return http.Response(
          jsonEncode(<String, dynamic>{"location": v2LocationFixture, "data": v2SessionFixture}),
          200,
        );
      },
    );
    expect(
      (await api.createSession(
        body: const V2CreateSessionBody(
          location: LocationPublicRef(directory: "/fixture/project"),
          title: null,
          agent: null,
          model: null,
        ),
      )).id,
      "session-fixture",
    );
  });

  test("mutation routes serialize typed bodies and preserve status errors", () async {
    final requests = <http.Request>[];
    final api = makeApi(
      handler: (request) async {
        requests.add(request);
        return request.url.path.endsWith("/interrupt")
            ? http.Response('{"interrupted":true}', 200)
            : http.Response("", 204);
      },
    );
    await api.renameSession(
      sessionId: "s",
      body: const V2RenameSessionBody(title: "Fixture"),
    );
    await api.switchAgent(
      sessionId: "s",
      body: const V2SwitchAgentBody(agent: "build"),
    );
    await api.switchModel(
      sessionId: "s",
      body: const V2SwitchModelBody(
        model: ModelRef(providerID: "fixture", id: "model", variant: null),
      ),
    );
    await api.command(
      sessionId: "s",
      body: const V2CommandBody(name: "fixture", text: "args", files: null, agents: null, skills: null, delivery: null),
    );
    await api.replyPermission(
      sessionId: "s",
      requestId: "p",
      body: const V2PermissionReplyBody(decision: PermissionReply.once, message: null),
    );
    await api.replyForm(
      sessionId: "s",
      formId: "f",
      body: FormReply(answer: FormAnswer.fromJson(const <String, dynamic>{"choice": "yes"})),
    );
    await api.cancelForm(sessionId: "s", formId: "f");
    await api.removeWorktree(
      body: const WorktreeRemoveInput(projectID: "p", directory: "/fixture/tree", force: false),
    );
    expect((await api.interrupt(sessionId: "s", resume: false)).interrupted, isTrue);
    await api.deleteSession(sessionId: "s");
    expect(requests.map((request) => "${request.method} ${request.url.path}"), <String>[
      "PATCH /api/session/s",
      "POST /api/session/s/agent",
      "POST /api/session/s/model",
      "POST /api/session/s/command",
      "POST /api/session/s/permission/p/reply",
      "POST /api/session/s/form/f/reply",
      "DELETE /api/session/s/form/f",
      "DELETE /api/worktree",
      "POST /api/session/s/interrupt",
      "DELETE /api/session/s",
    ]);
    expect(jsonDecode(requests[4].body), <String, dynamic>{"decision": "once"});
    expect(jsonDecode(requests[5].body), <String, dynamic>{
      "answer": <String, dynamic>{"choice": "yes"},
    });
    expect(requests[8].url.queryParameters, <String, String>{"resume": "false"});
  });

  test("reads and updates direct project responses", () async {
    const project = <String, dynamic>{
      "id": "project-fixture",
      "canonical": "/fixture/project",
      "time": <String, int>{"created": 1, "updated": 1, "active": 1},
      "sandboxes": <Object>[],
    };
    final api = makeApi(
      handler: (request) async {
        if (request.method == "PATCH") {
          expect(request.url.path, "/api/project/project-fixture");
          expect(jsonDecode(request.body), <String, dynamic>{"name": "Fixture"});
        } else {
          expect(request.url.path, "/api/project");
        }
        return http.Response(jsonEncode(request.method == "PATCH" ? project : <Object>[project]), 200);
      },
    );
    expect((await api.listProjects()).single.id, "project-fixture");
    expect(
      (await api.updateProject(
        projectId: "project-fixture",
        body: const V2UpdateProjectBody(
          canonical: null,
          name: "Fixture",
          icon: null,
          commands: null,
        ),
      )).id,
      "project-fixture",
    );
  });

  test("decodes prompt, synthetic and compaction inbox acknowledgements", () async {
    final api = makeApi(
      handler: (request) async {
        final operation = request.url.path.split("/").last;
        expect(request.method, "POST");
        expect(request.url.path, "/api/session/s/$operation");
        expect(
          jsonDecode(request.body),
          operation == "compact" ? <String, dynamic>{} : <String, dynamic>{"text": "fixture"},
        );
        return http.Response(
          jsonEncode(<String, dynamic>{
            "data": <String, dynamic>{
              "id": "inbox-$operation",
              "sessionID": "s",
              "time": <String, int>{"created": 1},
              "type": operation == "prompt"
                  ? "user"
                  : operation == "compact"
                  ? "compaction"
                  : "synthetic",
              "delivery": "queue",
              "payload": operation == "compact" ? <Object?>[null] : <String, dynamic>{"text": "fixture"},
            },
          }),
          200,
        );
      },
    );
    expect(
      (await api.prompt(
        sessionId: "s",
        body: const V2PromptBody(
          id: null,
          text: "fixture",
          files: null,
          agents: null,
          skills: null,
          delivery: null,
          resume: null,
        ),
      )).payload.text,
      "fixture",
    );
    expect(
      (await api.synthetic(
        sessionId: "s",
        body: const V2SyntheticBody(
          id: null,
          text: "fixture",
          description: null,
          delivery: null,
          resume: null,
        ),
      )).payload.text,
      "fixture",
    );
    expect(
      (await api.compact(sessionId: "s", body: const V2CompactBody(id: null, delivery: null))).payload.toJson(),
      <Object?>[null],
    );
  });

  test("retains decode causes without presenting response payloads", () async {
    final api = makeApi(handler: (_) async => http.Response("private prompt fixture", 200));
    await expectLater(
      api.getServerInfo(),
      throwsA(
        isA<V2DecodeException>()
            .having((error) => error.innerError, "cause", isA<FormatException>())
            .having((error) => error.toString(), "presentation", isNot(contains("private prompt fixture"))),
      ),
    );
    final failed = makeApi(handler: (_) async => http.Response("backend unavailable", 503));
    await expectLater(
      failed.getServerInfo(),
      throwsA(isA<OpenCodeApiException>().having((error) => error.statusCode, "status", 503)),
    );
  });
}
