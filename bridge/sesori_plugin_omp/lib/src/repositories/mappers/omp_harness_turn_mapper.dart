import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Drops the replayed user turns Oh My Pi wrote itself.
///
/// OMP talks to the model through developer-role messages: the leftover
/// background-process reminder, todo and plan-mode nudges, retry injections and
/// similar notices, each one whole `<system-…>` block (`prompts/system/*.md`).
/// They never stream live, but the ACP replay (`acp-agent.ts`
/// `#messageToReplayNotifications`) sends every developer message as a plain
/// `user_message_chunk`, with no role or `_meta` marker, so without this filter a
/// reload shows them as bubbles the user never typed.
///
/// The replay's text is the only signal, so a turn is dropped only when each of
/// its parts is text holding one whole block of OMP's harness tags, the set its
/// `session/harness-tags.ts` defines: `irc`, `tangent-notice` and `system-*`.
class const OmpHarnessTurnMapper() {
  static final RegExp _harnessBlock = RegExp(r"^<(irc|tangent-notice|system-[a-z][a-z-]*)(?:\s[^>]*)?>[\s\S]*</\1>$");

  /// [messages] without the user turns OMP's harness generated.
  List<PluginMessageWithParts> withoutHarnessTurns({required List<PluginMessageWithParts> messages}) => [
    for (final message in messages)
      if (!_isHarnessTurn(message: message)) message,
  ];

  bool _isHarnessTurn({required PluginMessageWithParts message}) =>
      message.info is PluginMessageUser &&
      message.parts.isNotEmpty &&
      message.parts.every((part) => part is PluginMessagePartText && _harnessBlock.hasMatch(part.text.trim()));
}
