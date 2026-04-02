import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/message_with_parts.dart";
import "models/provider_info.dart";
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
    Log.i("SessionMetadataGenerator: generate called for directory=$directory");
    try {
      final model = await _resolveModel();
      if (model == null) {
        Log.w("SessionMetadataGenerator: no suitable model found");
        return null;
      }

      final truncated = firstMessage.length > 500 ? firstMessage.substring(0, 500) : firstMessage;

      final session = await _api.createSession(directory: directory);
      Log.i("SessionMetadataGenerator: ephemeral session created: ${session.id}");
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
        Log.i("SessionMetadataGenerator: AI response received, parts=${response.parts.length}");

        return _parseResponse(response);
      } finally {
        Log.i("SessionMetadataGenerator: deleting ephemeral session");
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
    } catch (e, st) {
      Log.i("SessionMetadataGenerator: FAILED: $e\n$st");
      return null;
    }
  }

  /// Resolves the model to use for naming.
  ///
  /// Priority: small_model from config > smallest available model from
  /// connected providers (by name heuristic) > first provider's default.
  Future<({String providerID, String modelID})?> _resolveModel() async {
    // 1. Explicit small_model in config — user's choice, always wins.
    final config = await _api.getConfig();
    Log.i("SessionMetadataGenerator: config smallModel=${config.smallModel}, model=${config.model}");
    final explicit = _parseModelStr(config.smallModel);
    if (explicit != null) return explicit;

    // 2. Scan connected providers for the cheapest/fastest model.
    final providers = await _api.listProviders();
    final connectedIds = providers.connected.toSet();

    ({String providerID, String modelID})? best;
    var bestScore = -1;
    String? bestReleaseDate;

    for (final provider in providers.all) {
      if (!connectedIds.contains(provider.id)) continue;
      for (final model in provider.models.values) {
        if (model.status != "active") continue;
        final score = _smallModelScore(model: model);
        if (score > bestScore || (score == bestScore && _isNewer(model.releaseDate, bestReleaseDate))) {
          bestScore = score;
          best = (providerID: provider.id, modelID: model.id);
          bestReleaseDate = model.releaseDate;
        }
      }
    }

    Log.i("SessionMetadataGenerator: resolved model=${best?.providerID}/${best?.modelID} (score=$bestScore)");
    if (best != null) return best;

    // 3. Last resort: first connected provider's default.
    for (final connectedId in providers.connected) {
      final defaultModelId = providers.defaults[connectedId];
      if (defaultModelId != null && defaultModelId.isNotEmpty) {
        return (providerID: connectedId, modelID: defaultModelId);
      }
    }

    return null;
  }

  /// Scores a model by how "small" it is. Higher = more likely a small model.
  /// Returns 0 for models that don't match any known small-model pattern.
  static int _smallModelScore({required ProviderModel model}) {
    final name = model.name.toLowerCase();
    final family = model.family?.toLowerCase() ?? "";
    final id = model.id.toLowerCase();
    final fields = [name, family, id];

    for (final (pattern, score) in _smallModelPatterns) {
      if (fields.any(pattern.hasMatch)) return score;
    }
    return 0;
  }

  /// Known small-model indicators ordered by preference.
  /// Uses RegExp for word-boundary matching to avoid false positives
  /// (e.g. "minimax" should NOT match "mini").
  static final _smallModelPatterns = [
    (RegExp("haiku"), 100), // Anthropic's smallest
    (RegExp(r"nano\b"), 90), // OpenAI nano
    (RegExp("flash"), 80), // Google Flash
    (RegExp(r"\bmini\b"), 70), // OpenAI mini (not minimax)
  ];

  /// Returns true if [a] is a more recent release date than [b].
  /// Dates are ISO strings (e.g. "2025-07-10").
  /// Null is treated as newest — latest model versions often omit the date.
  static bool _isNewer(String? a, String? b) {
    if (a == null && b == null) return false;
    if (a == null) return true; // no date = latest
    if (b == null) return false; // current best has no date = latest
    return a.compareTo(b) > 0;
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
    final preview = mergedText.length > 200 ? mergedText.substring(0, 200) : mergedText;
    Log.i("SessionMetadataGenerator: mergedText length=${mergedText.length}, preview='$preview'");

    if (mergedText.isEmpty) {
      return null;
    }

    final parsed =
        _tryParseJson(raw: mergedText) ??
        _tryParseMarkdownJson(raw: mergedText) ??
        _tryExtractEmbeddedJson(raw: mergedText);
    Log.i("SessionMetadataGenerator: JSON parsed=${parsed != null}");
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
