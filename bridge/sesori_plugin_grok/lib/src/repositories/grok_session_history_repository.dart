import "../api/grok_session_store_api.dart";
import "../api/models/grok_session_notification_dto.dart";
import "../api/models/grok_session_store_dto.dart";
import "models/grok_session_replay_context.dart";

/// Derives immutable replay context from Grok's typed persisted session data.
/// Child prompts come only from each exact spawned child's first user-message
/// run; permission outcomes are intentionally absent because Grok 1.0.5 has no
/// verified persisted outcome record.
class GrokSessionHistoryRepository({required final GrokSessionStoreApi _api}) {
  Future<GrokSessionReplayContext> prepareReplayContext({
    required String cwd,
    required String rootSessionId,
  }) async {
    final prompts = <String, String>{};
    final seen = <String>{};
    await for (final envelope in _api.streamUpdates(cwd: cwd, sessionId: rootSessionId)) {
      if (envelope case GrokPersistedGrokSessionUpdateDto(:final params)) {
        if (params.update case final GrokSubagentSpawned spawn) {
          final childSessionId = spawn.childSessionId;
          if (childSessionId.isEmpty || !seen.add(childSessionId)) continue;
          final prompt = await _initialPrompt(cwd: cwd, childSessionId: childSessionId);
          if (prompt != null) prompts[childSessionId] = prompt;
        }
      }
    }
    return GrokSessionReplayContext(childPrompts: prompts);
  }

  Future<String?> _initialPrompt({required String cwd, required String childSessionId}) async {
    final prompt = StringBuffer();
    var started = false;
    await for (final envelope in _api.streamUpdates(cwd: cwd, sessionId: childSessionId)) {
      if (envelope case GrokPersistedAcpSessionUpdateDto(:final params) when params.sessionId == childSessionId) {
        if (params.update case GrokPersistedUserMessageChunkDto(:final content)) {
          started = true;
          if (content case GrokPersistedTextContentDto(:final text)) prompt.write(text);
          continue;
        }
      }
      if (started) break;
    }
    final value = prompt.toString();
    return value.trim().isEmpty ? null : value;
  }
}
