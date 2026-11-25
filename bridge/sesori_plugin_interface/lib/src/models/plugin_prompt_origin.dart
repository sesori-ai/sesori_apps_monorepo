/// Who wrote a prompt the bridge hands to a plugin.
///
/// A plugin whose harness can tell the model that text was not typed by the
/// user marks [sesori] prompts that way. Every other plugin ignores it.
enum PluginPromptOrigin() {
  /// The user typed it, possibly behind bridge-owned context notes.
  user,

  /// Sesori wrote or relayed it on its own: a notice, a wake-up, a scheduled
  /// run, a quota continuation or a send-to-session message.
  sesori,
}
