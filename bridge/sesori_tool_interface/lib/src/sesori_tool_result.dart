/// What a tool call answers the agent: plain text it reads.
sealed class const SesoriToolResult({required final String text});

final class const SesoriToolSuccess({required super.text}) extends SesoriToolResult;

/// A failure the agent can act on, sent as an `isError` result.
final class const SesoriToolFailure({required super.text}) extends SesoriToolResult;
