import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

/// What a computer switcher shows: every computer of the account, most
/// recently seen first, and which one the app works on.
@immutable
final class const ComputerSwitcherState({
  required final List<BridgeSummary> computers,

  /// The computer the app works on, or `null` while none is known yet (no
  /// stored pick and no connection that reached a computer).
  required final String? targetId,
}) {
  /// The computer to mark as current. Without a target yet the relay serves
  /// the most recently seen computer, the list's first, which is also the one
  /// the Projects header names.
  String? get currentId => targetId ?? computers.firstOrNull?.id;
}
