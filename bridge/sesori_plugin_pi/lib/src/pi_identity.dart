abstract final class PiPluginIdentity() {
  static const String id = "pi";
  static const String displayName = "Pi";

  /// The single primary agent Pi exposes in its catalog.
  static const String agentName = "pi";
}

/// What Pi users do when Pi has no usable provider login.
abstract final class PiLoginGuidance() {
  static const String actionHint =
      "Run `pi` on this machine and use /login to add a provider, then retry setup detection.";
}
