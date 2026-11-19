import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart" show PageAnswer, PendingPage;

part "agent_page.freezed.dart";
part "agent_page.g.dart";

/// How the user settled a page an agent sent.
@Freezed(unionKey: "type", fromJson: true, toJson: true, copyWith: false)
sealed class const AgentPageOutcome._() with _$AgentPageOutcome {
  /// Submitted, with the questions the user answered and the closing note.
  const factory answered({required List<PageAnswer> answers, required String? note}) = AgentPageAnswered;

  /// Closed without answering.
  const factory dismissed() = AgentPageDismissed;

  factory fromJson(Map<String, dynamic> json) => _$AgentPageOutcomeFromJson(json);
}

/// A stored page and, once the user settled it, how.
final class const StoredAgentPage({
  required final PendingPage page,

  /// Null while the page is pending.
  required final AgentPageOutcome? outcome,
});

sealed class const AgentPageEvent();

final class const AgentPageAsked({required final PendingPage page}) extends AgentPageEvent;

/// Answered or dismissed by the user. Emitted once per page, by the settle
/// that won.
final class const AgentPageSettled({
  required final PendingPage page,
  required final AgentPageOutcome outcome,
}) extends AgentPageEvent;
