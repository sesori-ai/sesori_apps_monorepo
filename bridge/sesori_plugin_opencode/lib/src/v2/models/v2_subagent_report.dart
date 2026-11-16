import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "openapi/session_message_synthetic.g.dart";

/// How a background sub-agent's period ended, from the report's
/// `metadata.state` (OpenCode's job status).
enum V2SubagentState() {
  completed,
  error,
  cancelled,
  unknown;

  static V2SubagentState parse({required Object? value}) {
    final state = values.where((state) => state != unknown && state.name == value).firstOrNull;
    if (state != null) return state;
    Log.d("OpenCode v2 sub-agent report has an unrecognized state $value; showing it as finished");
    return unknown;
  }
}

/// A background sub-agent's outcome, which OpenCode 2.3+ delivers to the
/// parent as a synthetic message tagged `metadata.source: "subagent"`. Its
/// text wraps the child's answer in a
/// `<subagent sessionID="…" state="…" description="…">` envelope.
final class const V2SubagentReport({
  required final String description,

  /// The agent as the report names it: a native ID or a display name.
  required final String agent,
  required final String? childSessionId,
  required final V2SubagentState state,

  /// The envelope's body: the child's answer, or its error. The whole text
  /// when the envelope does not parse.
  required final String body,
}) {
  static const _source = "subagent";
  static const _openTag = "<subagent";
  static const _closeTag = "</subagent>";

  /// The report [message] carries, or null for any other synthetic message.
  static V2SubagentReport? fromSynthetic({required SessionMessageSynthetic message}) {
    final metadata = message.metadata;
    if (metadata == null || metadata["source"] != _source) return null;
    final description = message.description;
    if (metadata["agent"] case final String agent when description != null) {
      final childId = metadata["childID"];
      return V2SubagentReport(
        description: description,
        agent: agent,
        childSessionId: childId is String ? childId : null,
        state: V2SubagentState.parse(value: metadata["state"]),
        body: _envelopeBody(text: message.text) ?? message.text,
      );
    }
    Log.w("OpenCode v2 sub-agent report lacks its agent or description; showing it as a plain message");
    return null;
  }

  /// The text between the opening tag and the closing one. OpenCode puts the
  /// body on the line after the opening tag, so the tag ends at the first
  /// closing quote followed by a newline. That holds whether or not attribute
  /// values are escaped, and when a single-line description contains `">`.
  static String? _envelopeBody({required String text}) {
    final trimmed = text.trim();
    if (!trimmed.startsWith(_openTag) || !trimmed.endsWith(_closeTag)) return null;
    final openEnd = trimmed.indexOf('">\n');
    if (openEnd < 0) return null;
    final bodyStart = openEnd + 3;
    final bodyEnd = trimmed.length - _closeTag.length;
    if (bodyStart > bodyEnd) return null;
    return trimmed.substring(bodyStart, bodyEnd).trim();
  }
}
