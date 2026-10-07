import "package:meta/meta.dart";

/// A stored tool part's identity: the page sent it as a summary, and its
/// output is fetched by this key.
typedef ToolOutputKey = ({String messageId, String partId});

/// Where an expanded summary tool part's output fetch stands.
@immutable
sealed class const ToolOutputFetch();

final class const ToolOutputLoading() extends ToolOutputFetch;

/// Each is null when the tool reported none.
final class const ToolOutputLoaded({required final String? output, required final String? error})
    extends ToolOutputFetch {
  @override
  bool operator ==(Object other) => other is ToolOutputLoaded && other.output == output && other.error == error;

  @override
  int get hashCode => Object.hash(output, error);
}

final class const ToolOutputFailed() extends ToolOutputFetch;
