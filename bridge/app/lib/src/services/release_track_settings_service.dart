import "package:sesori_shared/sesori_shared.dart" show BridgeReleaseTrack;

import "../repositories/bridge_settings_repository.dart";
import "../repositories/mappers/release_track_mapper.dart";

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
    return (await _settings.readCommittedSettings()).releaseTrack.toWire();
  }

  /// Stores [track] and returns the committed one, or null without storing
  /// anything when [track] is one this bridge does not know.
  Future<BridgeReleaseTrack?> update({required BridgeReleaseTrack track}) async {
    final releaseTrack = track.toReleaseTrack();
    if (releaseTrack == null) return null;
    return (await _settings.updateReleaseTrack(track: releaseTrack)).releaseTrack.toWire();
  }
}
