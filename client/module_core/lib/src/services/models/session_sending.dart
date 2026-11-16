import "package:meta/meta.dart";

/// A send of a session into another that has not ended: the source writes its
/// summary, or this app still looks for the outcome of a send whose answer
/// was lost. Either this app started it, or the bridge reports it for any
/// device.
@immutable
final class const SessionSending({
  /// The target's title when the send started; null when it had none.
  required final String? targetTitle,
}) {
  // Equal by value, so a repeated summary of the same send changes nothing.
  @override
  bool operator ==(Object other) => other is SessionSending && other.targetTitle == targetTitle;

  @override
  int get hashCode => targetTitle.hashCode;
}
