import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Builds the one `thread/sample` prompt for a side question. Codex has no
/// history parameter, so this side chat's earlier exchanges go inside the
/// prompt, which Codex caps at [maxBytes] UTF-8 bytes.
class const CodexSideQuestionPromptBuilder() {
  static const maxBytes = 4000;

  static const _historyHeader =
      "Earlier side questions about this conversation, oldest first. They are not part of the main conversation.";
  static const _shortenedMarker = "…";

  /// The prompt for [question] with as much of [history] as fits, or null
  /// when even the question alone does not fit. The oldest text goes first:
  /// the oldest kept answer is shortened when that is enough, otherwise the
  /// oldest exchange is dropped.
  String? build({required String question, required List<PluginSideExchange> history}) {
    final aloneBytes = _byteLength(
      value: _render(question: question, history: const []),
    );
    // Sizes are counted once so trimming a long side chat stays linear.
    final exchangeBytes = [for (final exchange in history) _byteLength(value: _renderExchange(exchange: exchange))];
    // The header line and the blank line closing the history.
    var historyBytes = _byteLength(value: _historyHeader) + 2 + exchangeBytes.fold<int>(0, (sum, bytes) => sum + bytes);
    for (var oldest = 0; oldest < history.length; oldest++) {
      final kept = history.sublist(oldest);
      final overflow = historyBytes + aloneBytes - maxBytes;
      if (overflow <= 0) return _render(question: question, history: kept);
      final shortened = _shortenedAnswer(answer: kept.first.answer, removeBytes: overflow);
      if (shortened != null) {
        return _render(
          question: question,
          history: [
            PluginSideExchange(question: kept.first.question, answer: shortened),
            ...kept.skip(1),
          ],
        );
      }
      historyBytes -= exchangeBytes[oldest];
    }
    return aloneBytes <= maxBytes ? _render(question: question, history: const []) : null;
  }

  String _renderExchange({required PluginSideExchange exchange}) =>
      "\nQuestion: ${exchange.question}\nAnswer: ${exchange.answer}\n";

  String _render({required String question, required List<PluginSideExchange> history}) {
    final buffer = StringBuffer();
    if (history.isNotEmpty) {
      buffer.writeln(_historyHeader);
      for (final exchange in history) {
        buffer.write(_renderExchange(exchange: exchange));
      }
      buffer.writeln();
    }
    buffer
      ..writeln("Side question: $question")
      ..writeln()
      ..write(
        "Answer the side question from what you already know about this conversation. "
        "Do not use tools. Reply with text only.",
      );
    return buffer.toString();
  }

  /// [answer] without its last [removeBytes] bytes, plus a marker, or null
  /// when nothing of it would be left.
  String? _shortenedAnswer({required String answer, required int removeBytes}) {
    final bytes = utf8.encode(answer);
    var keep = bytes.length - removeBytes - _byteLength(value: _shortenedMarker);
    if (keep <= 0) return null;
    // Never cut inside a multi-byte character.
    while (keep > 0 && (bytes[keep] & 0xC0) == 0x80) {
      keep--;
    }
    final kept = utf8.decode(bytes.sublist(0, keep)).trimRight();
    if (kept.isEmpty) return null;
    return "$kept$_shortenedMarker";
  }

  int _byteLength({required String value}) => utf8.encode(value).length;
}
