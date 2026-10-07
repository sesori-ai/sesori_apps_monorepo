import "package:sesori_shared/sesori_shared.dart";

/// Finds a search in a session's stored prompts.
class const PromptSearchMapper() {
  /// The rendered user messages in [messages] whose prompt text holds
  /// [pattern], in the order given, each with the words around its first
  /// match. Messages of other roles are skipped.
  List<SessionPromptSearchMatch> matchesOf({required List<MessageWithParts> messages, required RegExp pattern}) => [
    for (final message in messages)
      if (message.info is MessageUser && message.hasRenderableUserContent)
        if (message.promptText case final text?)
          if (pattern.firstMatch(text) case final match?)
            SessionPromptSearchMatch(
              messageId: message.info.id,
              excerpt: promptExcerpt(text: text, match: match),
            ),
  ];
}
