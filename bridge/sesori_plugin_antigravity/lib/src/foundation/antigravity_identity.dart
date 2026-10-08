import "package:acp_plugin/acp_plugin.dart";

/// Stable Sesori and upstream identities for Google Antigravity.
abstract final class AntigravityIdentity() {
  static const String pluginId = "antigravity";
  static const String displayName = "Antigravity";
  static const String upstreamAgentName = "antigravity-acp";

  /// Google 1.3.0 offers third-party account models only to recognized clients.
  /// Use its Zed-compatible model selector while retaining Sesori in the title.
  static const acpClientIdentity = AcpClientIdentity(
    name: "zed",
    title: "Sesori Bridge (Zed compatibility)",
    version: acpClientVersion,
  );
}
