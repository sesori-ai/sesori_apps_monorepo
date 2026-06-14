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

  /// Maps a persisted/CLI string to a track, defaulting unknown or null
  /// values to [stable] so a malformed config can never silently opt a user
  /// into pre-releases.
  static ReleaseTrack fromWire(String? value) {
    return switch (value) {
      'stable' => ReleaseTrack.stable,
      'internal' => ReleaseTrack.internal,
      _ => ReleaseTrack.stable,
    };
  }
}
