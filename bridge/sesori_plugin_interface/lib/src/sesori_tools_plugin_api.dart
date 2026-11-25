/// Optional: a started plugin whose backend can be too old to carry Sesori's
/// tools, although its descriptor declares `injectsSesoriTools`. A plugin
/// without it carries them whenever its descriptor declares so.
abstract interface class SesoriToolsPluginApi() {
  /// Whether this generation's sessions get Sesori's tools. Only then does a
  /// scheduled run's prompt ask the agent to use them.
  bool get carriesSesoriTools;
}
