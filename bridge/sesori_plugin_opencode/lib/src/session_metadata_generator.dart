import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/message_with_parts.dart";
import "models/send_message_sync_body.dart";
import "opencode_api.dart";
import "sanitize_branch_name.dart";

class SessionMetadataGenerator {
  final OpenCodeApi _api;

  SessionMetadataGenerator({required OpenCodeApi api}) : _api = api;

  Future<SessionMetadata?> generate({
    required String firstMessage,
    required String directory,
  }) async {
    try {
      final model = await _resolveModel();
      if (model == null) {
        Log.w("SessionMetadataGenerator: no suitable model found");
        return null;
      }

      final truncated = firstMessage.length > 500 ? firstMessage.substring(0, 500) : firstMessage;

      final session = await _api.createSession(directory: directory);
      try {
        final response = await _api.sendMessageSync(
          sessionId: session.id,
          directory: directory,
          body: SendMessageSyncBody(
            parts: [
              {"type": "text", "text": truncated},
            ],
            system: _systemPrompt,
            model: model,
          ),
        );

        return _parseResponse(response);
      } finally {
        try {
          await _api.deleteSession(
            sessionId: session.id,
            directory: directory,
          );
        } catch (e) {
          Log.w(
            "SessionMetadataGenerator: failed to delete ephemeral session: $e",
          );
        }
      }
    } catch (e) {
      Log.w("SessionMetadataGenerator: failed to generate metadata: $e");
      return null;
    }
  }

  /// Resolves the model to use for naming.
  ///
  /// Priority: small_model > model > first connected provider's default.
  Future<({String providerID, String modelID})?> _resolveModel() async {
    final config = await _api.getConfig();
    final configModel = _parseModelStr(config.smallModel) ?? _parseModelStr(config.model);
    if (configModel != null) return configModel;

    // Neither small_model nor model configured — pick the first
    // connected provider's default model from the provider list.
    final providers = await _api.listProviders();
    for (final connectedId in providers.connected) {
      final defaultModelId = providers.defaults[connectedId];
      if (defaultModelId != null && defaultModelId.isNotEmpty) {
        return (providerID: connectedId, modelID: defaultModelId);
      }
    }

    return null;
  }

  static ({String providerID, String modelID})? _parseModelStr(String? modelStr) {
    if (modelStr == null) return null;
    final slashIndex = modelStr.indexOf("/");
    if (slashIndex < 0) return null;
    final providerID = modelStr.substring(0, slashIndex);
    final modelID = modelStr.substring(slashIndex + 1);
    if (providerID.isEmpty || modelID.isEmpty) return null;
    return (providerID: providerID, modelID: modelID);
  }

  SessionMetadata? _parseResponse(MessageWithParts response) {
    final mergedText = response.parts.map((part) => part.text).whereType<String>().join();

    if (mergedText.isEmpty) {
      return null;
    }

    final parsed =
        _tryParseJson(raw: mergedText) ??
        _tryParseMarkdownJson(raw: mergedText) ??
        _tryExtractEmbeddedJson(raw: mergedText);
    if (parsed == null) {
      return null;
    }

    final title = parsed["title"];
    final branchName = parsed["branchName"];
    if (title is! String || branchName is! String) {
      return null;
    }

    final normalizedTitle = title.trim();
    final rawBranchName = branchName.trim();
    if (normalizedTitle.isEmpty || rawBranchName.isEmpty) {
      return null;
    }

    final sanitizedBranchName = sanitizeBranchName(raw: rawBranchName);
    if (sanitizedBranchName == null) {
      return null;
    }

    return SessionMetadata(
      title: normalizedTitle,
      branchName: sanitizedBranchName,
    );
  }

  Map<String, dynamic>? _tryParseJson({required String raw}) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _tryParseMarkdownJson({required String raw}) {
    final match = RegExp(
      r"```(?:json)?\s*(\{.*?\})\s*```",
      dotAll: true,
    ).firstMatch(raw);
    final captured = match?.group(1);
    if (captured == null) {
      return null;
    }
    return _tryParseJson(raw: captured);
  }

  /// Extracts a JSON object embedded in trailing text, e.g.
  /// `Here's the JSON: {"title": "Fix Bug", "branchName": "fix-bug"} hope that helps!`
  Map<String, dynamic>? _tryExtractEmbeddedJson({required String raw}) {
    final match = RegExp(r"\{[^{}]*\}").firstMatch(raw);
    final captured = match?.group(0);
    if (captured == null) {
      return null;
    }
    return _tryParseJson(raw: captured);
  }

  static const _systemPrompt =
      "Read the user's first message and generate session metadata. "
      "Return a concise title using 2 to 6 words. "
      "Return a git-branch-safe branch name in lowercase hyphenated form, max 60 chars. "
      "Respond ONLY with valid JSON in this exact shape: "
      '{"title":"...","branchName":"..."}'
      ". No markdown fences. No explanation. Only JSON.";
}
