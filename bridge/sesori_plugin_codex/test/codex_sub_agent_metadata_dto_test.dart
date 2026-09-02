import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/api/models/codex_thread_dto.dart";
import "package:test/test.dart";

// Fixtures mirror codex-cli 0.148.0 captures recorded in
// .plan/completed/claude-inline-subtasks/followups/codex-probe.md (ids redacted).
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
      });

      expect(thread.parentThreadId, "parent-1");
      expect(thread.agentNickname, "Raman");
      expect(thread.agentRole, isNull);
      expect(thread.threadSource, isNull);
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
