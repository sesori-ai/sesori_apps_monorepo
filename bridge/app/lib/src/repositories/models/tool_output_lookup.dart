/// The stored output and error of one tool part, looked up by its identity.
sealed class const ToolOutputLookup();

/// The part is a stored tool. [output] and [error] are null when the tool
/// reported none.
final class const ToolOutputFound({required final String? output, required final String? error})
    extends ToolOutputLookup;

/// No stored part has that identity, or it is not a tool.
final class const ToolOutputMissing() extends ToolOutputLookup;
