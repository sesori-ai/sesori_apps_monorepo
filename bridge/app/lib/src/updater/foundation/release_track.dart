import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

/// The release channel the bridge auto-updater follows.
///
/// - [stable]: only stable `vX.Y.Z` GitHub releases (the default).
/// - [internal]: the newest of stable releases and `vX.Y.Z-internal.N`
///   pre-releases, so internal users ride the per-merge internal channel.
enum ReleaseTrack {
  stable,
  internal;

  /// The string persisted in the bridge config file and accepted on the CLI.
  String get wireValue => name;

  /// Maps a persisted/CLI string to a track.
  ///
  /// A missing value (`null`) is the normal "not configured" case and resolves
  /// to [stable] silently. An unrecognized non-null value is a misconfiguration:
  /// it still falls back to [stable], but is logged via [Log.e] (stderr) so it
  /// is visible without polluting the machine-readable stdout that
  /// `--version`/`--help` rely on — track parsing runs during plugin selection
  /// for every command.
  static ReleaseTrack fromWire(String? value) {
    switch (value) {
      case null:
      case 'stable':
        return ReleaseTrack.stable;
      case 'internal':
        return ReleaseTrack.internal;
      default:
        Log.e("Unknown release track '$value' in bridge settings; defaulting to stable.");
        return ReleaseTrack.stable;
    }
  }
}
