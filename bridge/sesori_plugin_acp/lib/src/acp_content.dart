import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Shared parsing helpers for ACP `tool_call`/content payloads.
///
/// Both the live [AcpEventMapper] and the [AcpSessionLoader] replay path render
/// the same ACP shapes; these are the single implementation so the live and
/// history renderings cannot drift apart.

/// The display name for a tool from a `tool_call`/`tool_call_update`: its
/// `kind`, else `title`, else "tool". Fail-soft — a non-string field (schema
/// drift / malformed agent data) falls through rather than throwing during live
/// mapping or history replay.
String acpToolName(Map<String, dynamic> update) {
  final kind = update["kind"];
  if (kind is String && kind.isNotEmpty) return kind;
  final title = update["title"];
  if (title is String && title.isNotEmpty) return title;
  return "tool";
}

/// Maps an ACP tool-call status string onto the [PluginToolStatus] the mobile
/// tool renderer consumes. Tuned during end-to-end verification.
PluginToolStatus acpToolStatus(Object? raw) {
  return switch (raw) {
    "pending" => PluginToolStatus.pending,
    "in_progress" => PluginToolStatus.running,
    "completed" => PluginToolStatus.completed,
    "failed" => PluginToolStatus.error,
    _ => PluginToolStatus.pending,
  };
}

/// Tool output for a `tool_call`/`tool_call_update`: prefers an ACP `content`
/// block, else falls back to the harness `rawOutput` (cursor reports an executed
/// command's stdout/stderr there, not in `content`). Truncated to
/// [maxToolOutputLength] so the mobile tool renderer is not flooded.
String? acpToolOutputText(Map<String, dynamic> update) {
  final text =
      acpContentText(update["content"]) ?? acpRawOutputText(update["rawOutput"]);
  if (text == null || text.isEmpty) return null;
  return text.length > maxToolOutputLength
      ? "${text.substring(0, maxToolOutputLength)}…"
      : text;
}

/// Flattens a `rawOutput` block into displayable text. Exec-style tools report
/// `{exitCode, stdout, stderr}`; read/other tools report `{content}` (string or
/// ContentBlock(s)); some report a bare string.
String? acpRawOutputText(Object? raw) {
  if (raw is String) return raw.isEmpty ? null : raw;
  if (raw is! Map) return null;
  final map = raw.cast<String, dynamic>();
  final out = (map["stdout"] as String?)?.trimRight() ?? "";
  final err = (map["stderr"] as String?)?.trimRight() ?? "";
  if (out.isNotEmpty || err.isNotEmpty) {
    final buffer = StringBuffer(out);
    if (err.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write("\n");
      buffer.write(err);
    }
    return buffer.toString();
  }
  final content = acpContentText(map["content"])?.trimRight();
  if (content != null && content.isNotEmpty) return content;
  // A command that exited non-zero with no stdout/stderr/content would otherwise
  // render as a failed tool card with no diagnostic text — surface the exit code
  // so the failure is at least legible.
  final exitCode = map["exitCode"];
  if (exitCode is int && exitCode != 0) return "exited with code $exitCode";
  return null;
}

/// Extracts text from an ACP `ContentBlock` (`{type:text,text}`), the standard
/// tool-content wrapper (`{type:content,content:{type:text,text}}`), or a list
/// of either. The nested-`content` recursion is what lets a spec-compliant ACP
/// agent — which reports tool output through the wrapper rather than Cursor's
/// `rawOutput` — render non-blank tool cards and replayed history.
String? acpContentText(Object? content) {
  if (content is String) return content.isEmpty ? null : content;
  if (content is Map) {
    final text = content["text"];
    if (text is String && text.isNotEmpty) return text;
    // Unwrap the standard `{type:content, content:<block>}` tool-output shape.
    final nested = content["content"];
    return nested == null ? null : acpContentText(nested);
  }
  if (content is List) {
    final buffer = StringBuffer();
    for (final entry in content) {
      final text = acpContentText(entry);
      if (text != null) buffer.write(text);
    }
    final result = buffer.toString();
    return result.isEmpty ? null : result;
  }
  return null;
}
