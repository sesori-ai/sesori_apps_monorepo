import "claude_content_mapper.dart";

/// The backend-neutral fields used to render one Claude API failure.
typedef ClaudeMappedApiError = ({String name, String message});

/// Maps the API-failure shape shared by Claude's live and transcript paths.
ClaudeMappedApiError mapClaudeApiError({
  required List<ClaudeMappedContentBlock> blocks,
  required int? status,
}) {
  final text = [
    for (final block in blocks)
      if (block case ClaudeMappedTextContentBlock(:final text)) text,
  ].join("\n");
  return (
    name: claudeApiErrorName(status: status),
    message: text.isEmpty ? "Claude Code could not complete the API request." : text,
  );
}

/// The stable error category used by API failures with [status].
String claudeApiErrorName({required int? status}) =>
    status == 401 || status == 403 ? "authentication_failed" : "api_error";
