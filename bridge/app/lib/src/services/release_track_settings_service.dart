import "package:sesori_shared/sesori_shared.dart" show BridgeReleaseTrack;

import "../repositories/bridge_settings_repository.dart";
import "../updater/foundation/release_track.dart";

/// The auto-updater's release track, as the settings routes show it. The
/// updater reads the track once at startup, so a change applies from the
/// bridge's next start.
class const ReleaseTrackSettingsService({
  required final BridgeSettingsRepository _settings,

  /// Whether this install updates itself. One that does not follows no
  /// track, so the routes leave the setting out.
  required final bool _updatesItself,
}) {
  /// The stored track, or null when this install does not update itself.
  Future<BridgeReleaseTrack?> current() async {
    if (!_updatesItself) return null;
    return _toWire(track: (await _settings.readCommittedSettings()).releaseTrack);
  }

  /// Stores [track] and returns the committed one.
  Future<BridgeReleaseTrack> update({required ReleaseTrack track}) async {
    return _toWire(track: (await _settings.updateReleaseTrack(track: track)).releaseTrack);
  }

  /// The bridge's track for [track], or null for one it does not know.
  static ReleaseTrack? parse({required BridgeReleaseTrack track}) => switch (track) {
    BridgeReleaseTrack.stable => ReleaseTrack.stable,
    BridgeReleaseTrack.internal => ReleaseTrack.internal,
    BridgeReleaseTrack.unknown => null,
  };

  static BridgeReleaseTrack _toWire({required ReleaseTrack track}) => switch (track) {
    ReleaseTrack.stable => BridgeReleaseTrack.stable,
    ReleaseTrack.internal => BridgeReleaseTrack.internal,
  };
}
