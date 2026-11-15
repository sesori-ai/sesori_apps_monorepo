import "package:freezed_annotation/freezed_annotation.dart";

part "side_chat.freezed.dart";
part "side_chat.g.dart";

/// One stored side question and its answer. Times are milliseconds since the
/// epoch, like `SessionTime`. Carries prompt and answer text, so it has no
/// generated `toString`.
@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class SideChatExchange with _$SideChatExchange {
  const factory({
    required String id,
    required String question,
    required String answer,

    /// A harness note about how the answer was made, for example a fallback
    /// model notice; null when there is none.
    required String? answerNotice,
    required int askedAt,
    required int answeredAt,
  }) = _SideChatExchange;

  factory fromJson(Map<String, dynamic> json) => _$SideChatExchangeFromJson(json);
}

/// A side chat: the exchanges that share its [id], oldest first.
@Freezed(fromJson: true, toJson: true)
sealed class SideChat with _$SideChat {
  const factory({
    required String id,
    required List<SideChatExchange> exchanges,
  }) = _SideChat;

  factory fromJson(Map<String, dynamic> json) => _$SideChatFromJson(json);
}

/// Response body for `POST /session/side-chats`: the session's side chats,
/// newest first by their last answer.
@Freezed(fromJson: true, toJson: true)
sealed class SideChatListResponse with _$SideChatListResponse {
  const factory({
    required List<SideChat> sideChats,
  }) = _SideChatListResponse;

  factory fromJson(Map<String, dynamic> json) => _$SideChatListResponseFromJson(json);
}

/// Request body for `POST /session/side-question`. A null [sideChatId] starts
/// a new side chat, whose id the bridge mints.
@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class AskSideQuestionRequest with _$AskSideQuestionRequest {
  const factory({
    required String sessionId,
    required String? sideChatId,
    required String question,
  }) = _AskSideQuestionRequest;

  factory fromJson(Map<String, dynamic> json) => _$AskSideQuestionRequestFromJson(json);
}

/// Why the bridge gave no answer to a side question.
enum SideQuestionRefusal() {
  /// This session's harness has no side questions.
  harnessUnsupported,

  /// The installed harness is too old for side questions, or can't ask while
  /// a turn runs.
  harnessUpdateRequired,

  /// The session has no turn yet, so there is nothing to answer from.
  noTurnYet,

  /// The question, with its side chat, is too long for the harness.
  tooLong,

  /// The model gave no usable answer.
  noAnswer,

  /// A reason this app does not know yet.
  unknown,
}

/// Response body for `POST /session/side-question`.
@Freezed(unionKey: "type", fallbackUnion: "unknown", copyWith: false, fromJson: true, toJson: true)
sealed class AskSideQuestionResponse with _$AskSideQuestionResponse {
  /// The answer, stored as [exchange] in the side chat [sideChatId].
  const factory answered({
    required String sideChatId,
    required SideChatExchange exchange,
  }) = AskSideQuestionAnswered;

  /// No answer, for [reason]. Nothing was stored.
  const factory refused({
    @JsonKey(unknownEnumValue: SideQuestionRefusal.unknown) required SideQuestionRefusal reason,
  }) = AskSideQuestionRefused;

  /// A response kind from a newer bridge.
  const factory unknown() = AskSideQuestionUnknown;

  factory fromJson(Map<String, dynamic> json) => _$AskSideQuestionResponseFromJson(json);
}
