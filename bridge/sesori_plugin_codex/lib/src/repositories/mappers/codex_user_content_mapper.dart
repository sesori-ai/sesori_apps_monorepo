final class const CodexUserContentMapper() {
  String? mapContentText({required Iterable<String> textParts}) {
    final visible = <String>[];
    for (final text in textParts) {
      if (text.isEmpty || _isGeneratedCodexContext(text: text)) continue;
      final mapped = _stripBridgeContext(text: text);
      if (mapped != null && mapped.isNotEmpty) visible.add(mapped);
    }
    return visible.isEmpty ? null : visible.join();
  }

  String? mapSubmittedText({required String? text}) {
    if (text == null || text.isEmpty) return null;
    return _stripBridgeContext(text: text);
  }

  String? _stripBridgeContext({required String text}) {
    const marker = "[SYSTEM CONTEXT \u2014 IMPORTANT]";
    final markerIndex = text.indexOf(marker);
    if (markerIndex < 0 || text.substring(0, markerIndex).trim().isNotEmpty) {
      return text;
    }
    final envelopeEnd = text.indexOf("\n---", markerIndex + marker.length);
    if (envelopeEnd < 0) return text;
    final trailing = text.substring(envelopeEnd + "\n---".length).trim();
    return trailing.isEmpty ? null : trailing;
  }

  bool _isGeneratedCodexContext({required String text}) {
    final normalized = text.trim();
    return _GeneratedContextTag.values.any((tag) => tag.wraps(normalized)) ||
        _generatedRepositoryInstructions.hasMatch(normalized);
  }
}

enum _GeneratedContextTag(final String wireName) {
  recommendedPlugins("recommended_plugins"),
  environmentContext("environment_context"),
  turnAborted("turn_aborted");

  bool wraps(String text) => text.startsWith("<$wireName>") && text.endsWith("</$wireName>");
}

final _generatedRepositoryInstructions = RegExp(
  r"^# AGENTS\.md instructions(?: for [^\r\n]+)?\r?\n\r?\n"
  r"<INSTRUCTIONS>(?:\r?\n)?[\s\S]*?(?:\r?\n)?</INSTRUCTIONS>$",
);
