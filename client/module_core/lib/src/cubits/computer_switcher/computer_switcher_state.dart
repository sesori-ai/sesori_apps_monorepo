import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

/// What a computer switcher shows: every computer of the account, most
/// recently seen first, which one the app works on, and which one is this
/// surface's own.
@immutable
final class const ComputerSwitcherState({
  required final List<BridgeSummary> computers,

  /// The computer the app works on, or `null` while none is known yet (no
  /// stored pick and no connection that reached a computer).
  required final String? targetId,

  /// The bridge this surface supervises on its own computer, or `null` when it
  /// supervises none (the phone) or its id is not known yet.
  required final String? localId,
}) {
  /// The computer to mark as current. Without a target that is this computer;
  /// a surface without one of its own is served the most recently seen
  /// computer, the list's first, which is also the one the Projects header
  /// names.
  String? get currentId => targetId ?? localId ?? computers.firstOrNull?.id;

  /// Whether the app works on a computer other than this surface's own. A
  /// missing target counts as this computer.
  bool get viewsAnotherComputer => targetId != null && targetId != localId;

  /// Whether [bridgeId] is the computer this surface runs on. Never true on a
  /// surface without a computer of its own (the phone).
  bool isThisComputer({required String bridgeId}) => bridgeId == localId;

  /// Whether [bridgeId] can be removed from the account: a listed computer
  /// that is offline and not this surface's own. An online one would only be
  /// taken off the list until its bridge reports in again, and this computer
  /// stops being reachable by turning its bridge off instead.
  bool canRemove({required String bridgeId}) =>
      !isThisComputer(bridgeId: bridgeId) &&
      computers.any((computer) => computer.id == bridgeId && computer.status == BridgeRegistrationStatus.inactive);
}
