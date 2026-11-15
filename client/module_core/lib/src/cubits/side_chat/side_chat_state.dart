import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "side_chat_state.freezed.dart";

/// One session's side chats, while the side sheet or panel is open.
@Freezed()
sealed class SideChatState with _$SideChatState {
  /// The session's side chats are loading.
  const factory loading() = SideChatLoading;

  /// The side chats could not be loaded; `reload` tries again.
  const factory loadFailed() = SideChatLoadFailed;

  const factory ready({
    /// The session's other side chats, newest first by their last answer.
    /// The chat shown in [thread] is never among them.
    required List<SideChat> earlierChats,
    required SideChatThread thread,
    required SideQuestionAsk ask,
  }) = SideChatReady;
}

/// The side chat being shown.
@Freezed()
sealed class SideChatThread with _$SideChatThread {
  /// A chat with no exchanges yet; its first answer creates it on the bridge.
  const factory newChat() = SideChatNewThread;

  /// A stored chat, with its exchanges oldest first.
  const factory existing({required SideChat chat}) = SideChatExistingThread;
}

/// The latest question asked in the shown chat, until it is answered. Its
/// question text has no generated `toString`, because it is prompt content.
@Freezed(toStringOverride: false)
sealed class SideQuestionAsk with _$SideQuestionAsk {
  /// Nothing is being asked.
  const factory idle() = SideQuestionIdle;

  /// [question] was sent and its answer hasn't arrived.
  const factory waiting({required String question}) = SideQuestionWaiting;

  /// The bridge gave no answer to [question], for [reason]. Nothing was
  /// stored.
  const factory refused({required String question, required SideQuestionRefusal reason}) = SideQuestionRefused;

  /// Asking [question] failed before the bridge answered.
  const factory failed({required String question}) = SideQuestionFailed;
}
