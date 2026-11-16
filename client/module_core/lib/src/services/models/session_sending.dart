import "package:meta/meta.dart";

/// A send of a session into another that this app started and that has not
/// ended: the source writes its summary, or the app still looks for the
/// outcome of a send whose answer was lost.
@immutable
final class const SessionSending({
  /// The target's title when the send started; null when it had none.
  required final String? targetTitle,
});
