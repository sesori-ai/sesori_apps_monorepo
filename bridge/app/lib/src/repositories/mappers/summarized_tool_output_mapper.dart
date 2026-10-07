import "package:sesori_shared/sesori_shared.dart";

/// Projects a stored message for a transcript page whose app fetches tool
/// output when a row expands.
extension SummarizedToolOutputMapping on MessageWithParts {
  /// This message with each finished tool that has output or error replaced
  /// by its summary, which the app expands through `POST /session/tool-output`.
  /// Running tools stay full, because their output still changes, and so do
  /// subtasks, whose task state is not a tool part.
  MessageWithParts withSummarizedToolOutput() => copyWith(
    parts: [
      for (final part in parts)
        switch (part) {
          MessagePartTool(
            state: ToolStateFull(
              :final status,
              :final title,
              :final shellCommand,
              :final output,
              :final error,
              :final attachments,
            ),
          )
              when _isFinished(status: status) && (output != null || error != null) =>
            part.copyWith(
              state: ToolState.summary(
                status: status,
                title: title,
                shellCommand: shellCommand,
                attachments: attachments,
              ),
            ),
          _ => part,
        },
    ],
  );

  static bool _isFinished({required ToolStatus status}) => switch (status) {
    ToolStatus.completed || ToolStatus.error || ToolStatus.cancelled => true,
    ToolStatus.pending || ToolStatus.running || ToolStatus.unknown => false,
  };
}
