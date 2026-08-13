import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "bridge_identity_state.freezed.dart";

/// The machine the app is paired with, as the UI can name it: the bridge this
/// account has registered with the auth server.
///
/// Resolving it is a network round trip, so the answer lands after the surfaces
/// that name it are already on screen. Keeping "no answer yet" ([pending])
/// distinct from "nothing to name" ([unnamed]) is what lets those surfaces hold
/// the row's space while the lookup runs — instead of laying out without it and
/// pushing their content around when the name arrives — and what stops a failed
/// lookup from holding a placeholder forever.
@Freezed()
sealed class BridgeIdentityState with _$BridgeIdentityState {
  /// The lookup has not answered yet: nothing can be named, and consumers show
  /// their loading placeholder (the top navigation shimmers a subtitle
  /// skeleton) in the row's place.
  const factory pending() = BridgeIdentityPending;

  /// [bridge] is the machine to name — the account's most recently seen
  /// registered bridge.
  const factory named({required BridgeSummary bridge}) = BridgeIdentityNamed;

  /// The lookup answered with no machine to name: the account has never
  /// registered a bridge, or the fail-soft fetch came back with nothing (e.g.
  /// the phone itself is offline). Consumers drop the row.
  const factory unnamed() = BridgeIdentityUnnamed;
}
