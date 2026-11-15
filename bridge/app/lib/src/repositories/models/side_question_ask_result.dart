import "package:sesori_shared/sesori_shared.dart";

/// Outcome of one side question asked of a session's harness.
sealed class const SideQuestionAskResult();

/// The whole answer, not stored yet.
final class const SideQuestionAnswered({
  required final String text,
  required final String? notice,
}) extends SideQuestionAskResult;

/// No answer, for [reason].
final class const SideQuestionRefused({required final SideQuestionRefusal reason}) extends SideQuestionAskResult;
