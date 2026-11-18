import "dart:math" show max;

import "package:sesori_shared/sesori_shared.dart";

/// Renders a session's transcript as one Markdown document, for another
/// session's agent to read from a file.
///
/// Keeps the conversation itself: text verbatim, one line per tool with its
/// error and capped output, and markers for attachments, sub-agents and
/// compactions. Reasoning, step markers, snapshots, patches, agent switches
/// and retries are left out; some harnesses encrypt reasoning, and the rest
/// carry nothing a reader needs.
class const SessionTranscriptMarkdownBuilder() {
  /// Tool output and errors longer than this many characters are cut, with a
  /// note saying how many characters were left out.
  static const maxToolTextLength = 4096;

  static final _backtickRun = RegExp("`+");
  static final _lineBreak = RegExp(r"\s*\n\s*");

  /// The Markdown for [messages] of [session], which runs on the harness named
  /// [harnessName], as exported at [exportedAt]. Times are written in UTC.
  String build({
    required Session session,
    required String harnessName,
    required DateTime exportedAt,
    required List<MessageWithParts> messages,
  }) {
    final title = session.title?.trim();
    final created = session.time?.created;
    final blocks = <String>[
      "# ${title == null || title.isEmpty ? "Untitled session" : title}",
      [
        "- Harness: $harnessName",
        "- Directory: ${session.directory}",
        if (created != null) "- Created: ${_formatMillis(millis: created)}",
        "- Exported: ${_formatTime(time: exportedAt)}",
        "- Messages: ${messages.length}",
      ].join("\n"),
      if (messages.isEmpty) "_No messages._",
      for (final (index, message) in messages.indexed) ...[
        _heading(number: index + 1, message: message.info),
        if (message.info case MessageError(:final errorName, :final errorMessage))
          "**$errorName**\n\n${_cappedBlock(text: errorMessage)}",
        for (final part in message.parts) ?_part(part: part),
      ],
    ];
    return "${blocks.join("\n\n")}\n";
  }

  static String _heading({required int number, required Message message}) {
    final (role, details, time) = switch (message) {
      MessageUser(:final time) => ("User", const <String>[], time),
      MessageAssistant(:final sender, :final agent, :final providerID, :final modelID, :final time) => (
        switch (sender) {
          MessageSender.agent => "Assistant",
          MessageSender.sesori => "Sesori",
          MessageSender.system || MessageSender.unknown => "System",
        },
        _agentAndModel(agent: agent, providerID: providerID, modelID: modelID),
        time,
      ),
      MessageError(:final agent, :final providerID, :final modelID, :final time) => (
        "Error",
        _agentAndModel(agent: agent, providerID: providerID, modelID: modelID),
        time,
      ),
    };
    return [
      "## $number. $role",
      if (details.isNotEmpty) " (${details.join(", ")})",
      if (time != null) " · ${_formatMillis(millis: time.created)}",
    ].join();
  }

  static List<String> _agentAndModel({
    required String? agent,
    required String? providerID,
    required String? modelID,
  }) => [
    if (agent != null && agent.isNotEmpty) "agent: $agent",
    if (modelID != null && modelID.isNotEmpty)
      "model: ${providerID != null && providerID.isNotEmpty ? "$providerID/$modelID" : modelID}",
  ];

  /// The block for [part], or null when the part is left out.
  static String? _part({required MessagePart part}) => switch (part) {
    MessagePartText(:final text) => text.trim().isEmpty ? null : text,
    MessagePartTool(:final tool, :final state) => _tool(tool: tool, state: state),
    MessagePartFile(:final attachment) => _attachment(attachment: attachment),
    MessagePartSubtask(:final description, :final agent) =>
      "[Sub-agent: ${_nonBlank(text: description) ?? _nonBlank(text: agent) ?? "task"}]",
    MessagePartCompaction(state: CompactionStateCompleted()) => "[Context compacted]",
    MessagePartCompaction(state: CompactionStateRunning() || CompactionStateFailed()) ||
    // A patch part names no files, and the tool lines already show the edits.
    MessagePartPatch() ||
    MessagePartReasoning() ||
    MessagePartStepStart() ||
    MessagePartStepFinish() ||
    MessagePartSnapshot() ||
    MessagePartAgent() ||
    MessagePartRetry() => null,
  };

  static String _tool({required String tool, required ToolState state}) {
    final (status, title, shellCommand, output, error, attachments) = switch (state) {
      ToolStateFull(
        :final status,
        :final title,
        :final shellCommand,
        :final output,
        :final error,
        :final attachments,
      ) =>
        (status, title, shellCommand, output, error, attachments),
      ToolStateSummary(:final status, :final title, :final shellCommand, :final attachments) => (
        status,
        title,
        shellCommand,
        null,
        null,
        attachments,
      ),
    };
    final summary = _nonBlank(text: shellCommand) ?? _nonBlank(text: title);
    return [
      [
        "**Tool** ${_inlineCode(text: tool.isEmpty ? "tool" : tool)} (${status.name})",
        if (summary != null) ": ${_inlineCode(text: summary)}",
      ].join(),
      if (error != null && error.trim().isNotEmpty) "Error:\n${_cappedBlock(text: error)}",
      if (output != null && output.trim().isNotEmpty) _cappedBlock(text: output),
      for (final attachment in attachments) ?_attachment(attachment: attachment),
    ].join("\n\n");
  }

  static String? _attachment({required MessageAttachment attachment}) {
    final (filename, mime) = switch (attachment) {
      MessageAttachmentInlineImage(:final filename, :final mime) ||
      MessageAttachmentRemoteUrl(:final filename, :final mime) ||
      MessageAttachmentStoredImage(:final filename, :final mime) ||
      MessageAttachmentMetadata(:final filename, :final mime) => (filename, mime),
      MessageAttachmentUnknown() => (null, null),
    };
    if (mime == null) return "[Attached file]";
    return "[Attached file: ${filename == null || filename.isEmpty ? "unnamed" : filename} ($mime)]";
  }

  /// [text] in a fenced block, cut to [maxToolTextLength] characters with a
  /// note after the block when it is longer.
  static String _cappedBlock({required String text}) {
    // A string with no more code units than the cap has no more characters.
    if (text.length <= maxToolTextLength) return _fenced(text: text);
    final characters = text.runes.toList(growable: false);
    if (characters.length <= maxToolTextLength) return _fenced(text: text);
    final kept = String.fromCharCodes(characters.take(maxToolTextLength));
    return "${_fenced(text: kept)}\n[truncated: ${characters.length - maxToolTextLength} characters]";
  }

  /// A fence longer than any backtick run in [text], so the text cannot close
  /// it early.
  static String _fenced({required String text}) {
    final fence = "`" * max(3, _longestBacktickRun(text: text) + 1);
    return "$fence\n${text.endsWith("\n") ? text : "$text\n"}$fence";
  }

  /// [text] on one line as a code span, with line breaks turned into spaces.
  static String _inlineCode({required String text}) {
    final line = text.replaceAll(_lineBreak, " ").trim();
    final fence = "`" * (_longestBacktickRun(text: line) + 1);
    final padding = line.startsWith("`") || line.endsWith("`") ? " " : "";
    return "$fence$padding$line$padding$fence";
  }

  static int _longestBacktickRun({required String text}) =>
      _backtickRun.allMatches(text).fold(0, (longest, match) => max(longest, match.end - match.start));

  static String _formatMillis({required int millis}) =>
      _formatTime(time: DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true));

  static String _formatTime({required DateTime time}) {
    final utc = time.toUtc();
    return "${utc.year.toString().padLeft(4, "0")}-${_twoDigits(value: utc.month)}-${_twoDigits(value: utc.day)} "
        "${_twoDigits(value: utc.hour)}:${_twoDigits(value: utc.minute)}:${_twoDigits(value: utc.second)} UTC";
  }

  static String _twoDigits({required int value}) => value.toString().padLeft(2, "0");

  static String? _nonBlank({required String? text}) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
