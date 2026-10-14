import "package:meta/meta.dart";

/// A computer that was just linked to the account, to announce with an offer
/// to switch to it. Every announcement is a distinct value, so a listener sees
/// each one even when two name the same computer.
@immutable
final class const LinkedComputerAlert({
  required final String bridgeId,
  required final String name,
});
