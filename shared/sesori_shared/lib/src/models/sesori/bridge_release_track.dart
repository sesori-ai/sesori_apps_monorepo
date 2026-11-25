/// The release channel a self-updating bridge follows.
enum BridgeReleaseTrack() {
  /// Stable releases only.
  stable,

  /// Stable releases and internal pre-releases.
  internal,

  /// A track this build does not know.
  unknown,
}
