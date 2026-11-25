import "package:sesori_shared/sesori_shared.dart" show BridgeReleaseTrack;

import "../../updater/foundation/release_track.dart";

extension ReleaseTrackMapper on ReleaseTrack {
  BridgeReleaseTrack toWire() => switch (this) {
    ReleaseTrack.stable => BridgeReleaseTrack.stable,
    ReleaseTrack.internal => BridgeReleaseTrack.internal,
  };
}

extension BridgeReleaseTrackMapper on BridgeReleaseTrack {
  /// The updater's track, or null for one this bridge does not know.
  ReleaseTrack? toReleaseTrack() => switch (this) {
    BridgeReleaseTrack.stable => ReleaseTrack.stable,
    BridgeReleaseTrack.internal => ReleaseTrack.internal,
    BridgeReleaseTrack.unknown => null,
  };
}
