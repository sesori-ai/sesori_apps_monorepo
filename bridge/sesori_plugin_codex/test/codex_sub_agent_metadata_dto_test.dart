import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/api/models/codex_thread_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_thread_repository.dart";
import "package:test/test.dart";

// Fixtures mirror codex-cli 0.148.0 captures recorded in
// .plan/active/claude-inline-subtasks/followups/codex-probe.md (ids redacted).
void main() {
  group("CodexThreadDto", () {
    test("decodes sub-agent parentage from thread/read of a live child", () {
      final thread = CodexThreadDto.fromJson(const {
        "id": "child-1",
        "parentThreadId": "parent-1",
        "agentNickname": "Raman",
        "agentRole": null,
        "threadSource": null,
        "name": null,
        "cwd": "/tmp/project",
        "modelProvider": "openai",
        "createdAt": 1788356424,
        "updatedAt": 1788356444,
        "status": {"type": "active", "activeFlags": <String>[]},
        "canAcceptDirectInput": false,
        "turns": [
          {
            "id": "child-turn-1",
            "items": [
              {
                "type": "userMessage",
                "content": [
                  {"type": "text", "text": "Inspect child lifecycle."},
                ],
              },
            ],
          },
        ],
      });

      expect(thread.parentThreadId, "parent-1");
      expect(thread.agentNickname, "Raman");
      expect(thread.agentRole, isNull);
      expect(thread.threadSource, isNull);
      expect(thread.turns.single.id, "child-turn-1");
      final userItem = thread.turns.single.items.single as CodexThreadUserMessageItemDto;
      expect((userItem.content.single as CodexThreadTextContentDto).text, "Inspect child lifecycle.");
    });

    test("thread/read selects the child prompt by exact turn provenance", () async {
      final transport = _ThreadReadTransport(
        turns: const [
          {
            "id": "parent-turn",
            "items": [
              {
                "type": "userMessage",
                "content": [
                  {"type": "text", "text": "Parent prompt copied into child."},
                ],
              },
            ],
          },
          {
            "id": "child-turn",
            "items": [
              {"type": "futureItem", "payload": "ignored"},
              {
                "type": "userMessage",
                "content": [
                  {"type": "input_text", "text": "rollout-only vocabulary"},
                  {"type": "text", "text": "Actual child prompt."},
                ],
              },
            ],
          },
        ],
      );
      final repository = CodexThreadRepository(
        appServerApi: CodexAppServerApi(client: transport),
      );

      await repository.readThread(threadId: "child-1");

      expect(transport.params, {"threadId": "child-1", "includeTurns": true});
      expect(
        repository.initialUserPrompt(threadId: "child-1", turnId: "child-turn"),
        "Actual child prompt.",
      );
      expect(repository.initialUserPrompt(threadId: "child-1", turnId: null), isNull);
      expect(repository.initialUserPrompt(threadId: "child-1", turnId: "unobserved-turn"), isNull);
    });

    test("retains provenance-matched prompts until their thread is forgotten", () async {
      final repository = CodexThreadRepository(
        appServerApi: CodexAppServerApi(
          client: _ThreadReadTransport(
            turns: const [
              {
                "id": "child-turn",
                "items": [
                  {
                    "type": "userMessage",
                    "content": [
                      {"type": "text", "text": "Inspect child lifecycle."},
                    ],
                  },
                ],
              },
            ],
          ),
        ),
      );

      await repository.readThread(threadId: "child-1");

      expect(
        repository.initialUserPrompt(threadId: "child-1", turnId: "child-turn"),
        "Inspect child lifecycle.",
      );
      await repository.readThread(threadId: "child-2");
      repository.forgetThread(threadId: "child-1");
      expect(repository.initialUserPrompt(threadId: "child-1", turnId: "child-turn"), isNull);
      expect(
        repository.initialUserPrompt(threadId: "child-2", turnId: "child-turn"),
        "Inspect child lifecycle.",
      );
    });

    test("unknown thread items and user content decode as ignored variants", () {
      final thread = CodexThreadDto.fromJson(const {
        "id": "child-1",
        "turns": [
          {
            "id": "child-turn",
            "items": [
              {"type": "futureItem", "payload": "ignored"},
              {
                "type": "userMessage",
                "content": [
                  {"type": "input_text", "text": "not app-server UserInput"},
                  {"type": "text", "text": "Native text."},
                ],
              },
            ],
          },
        ],
      });

      expect(thread.turns.single.items.first, isA<CodexThreadUnknownItemDto>());
      final userMessage = thread.turns.single.items.last as CodexThreadUserMessageItemDto;
      expect(userMessage.content.first, isA<CodexThreadUnknownContentDto>());
      expect((userMessage.content.last as CodexThreadTextContentDto).text, "Native text.");
    });

    test("decodes known thread sources and falls back to unknown", () {
      CodexThreadSource? source(String value) => CodexThreadDto.fromJson({
        "id": "t",
        "threadSource": value,
      }).threadSource;

      expect(source("subAgent"), CodexThreadSource.subAgent);
      expect(source("subAgentReview"), CodexThreadSource.subAgentReview);
      expect(source("subAgentCompact"), CodexThreadSource.subAgentCompact);
      expect(source("subAgentThreadSpawn"), CodexThreadSource.subAgentThreadSpawn);
      expect(source("subAgentOther"), CodexThreadSource.subAgentOther);
      expect(source("guardian"), CodexThreadSource.unknown);
    });

    test("root threads decode with null parentage", () {
      final envelope = CodexThreadEnvelopeDto.fromJson(const {
        "thread": {
          "id": "root-1",
          "parentThreadId": null,
          "agentNickname": null,
          "agentRole": null,
          "threadSource": null,
          "cwd": "/tmp/project",
        },
      });

      expect(envelope.thread?.id, "root-1");
      expect(envelope.thread?.parentThreadId, isNull);
      expect(envelope.thread?.threadSource, isNull);
    });
  });

  group("CodexRolloutSessionMetadataPayloadDto", () {
    test("decodes the child rollout session_meta", () {
      final line = CodexRolloutLineDto.fromJson(const {
        "timestamp": "2026-09-02T16:40:28Z",
        "type": "session_meta",
        "payload": {
          "id": "child-1",
          "timestamp": "2026-09-02T16:40:28Z",
          "cwd": "/tmp/project",
          "originator": "sesori-probe",
          "cli_version": "0.148.0",
          "model_provider": "openai",
          "parent_thread_id": "parent-1",
          "thread_source": "subagent",
          "agent_nickname": "Raman",
          "agent_path": "/root/sleep_then_done",
          "source": {
            "subagent": {
              "thread_spawn": {"parent_thread_id": "parent-1", "depth": 1},
            },
          },
          "forked_from_id": "parent-1",
        },
      });

      final payload = (line as CodexRolloutSessionMetadataLineDto).payload;
      expect(payload.parentThreadId, "parent-1");
      expect(payload.threadSource, CodexRolloutThreadSource.subagent);
      expect(payload.agentNickname, "Raman");
      expect(payload.agentPath, "/root/sleep_then_done");
    });

    test("root session_meta decodes with null parentage and unknown sources fall back", () {
      final root = CodexRolloutSessionMetadataPayloadDto.fromJson(const {
        "id": "root-1",
        "cwd": "/tmp/project",
        "cli_version": "0.148.0",
        "source": "vscode",
      });
      expect(root.parentThreadId, isNull);
      expect(root.threadSource, isNull);
      expect(root.agentNickname, isNull);
      expect(root.agentPath, isNull);

      final drifted = CodexRolloutSessionMetadataPayloadDto.fromJson(const {
        "id": "t",
        "thread_source": "guardian",
      });
      expect(drifted.threadSource, CodexRolloutThreadSource.unknown);
    });
  });
}

final class _ThreadReadTransport({required final List<Map<String, Object?>> turns}) implements CodexAppServerTransport {
  Map<String, dynamic>? params;

  @override
  Stream<CodexServerNotification> get notifications => const Stream.empty();

  @override
  Future<dynamic> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    expect(method, "thread/read");
    this.params = (params! as Map).cast<String, dynamic>();
    return {
      "thread": {
        "id": this.params!["threadId"],
        "parentThreadId": "parent-1",
        "turns": turns,
      },
    };
  }
}
