/// Identity constants for the Grok Build harness plugin.
///
/// The transport keeps plugin IDs as strings; client-side built-in branding
/// recognizes the stable [id] only after the plugin is activated.
abstract final class GrokPluginIdentity() {
  static const String id = "grok";
  static const String displayName = "Grok Build";
}
