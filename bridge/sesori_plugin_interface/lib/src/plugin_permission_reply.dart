/// Reply to a permission request from the AI assistant.
///
/// Mirrors the OpenCode `Permission.Reply` enum:
/// - [once] — approve just this one tool call
/// - [always] — approve future requests matching the suggested patterns for the rest of the session
/// - [reject] — deny the request
enum PluginPermissionReply { once, always, reject }
