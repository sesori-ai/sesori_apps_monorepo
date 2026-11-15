import "package:sesori_shared/sesori_shared.dart";

/// What the bridge stamps on the user message that fulfils a prompt it sent.
/// A prompt is either a command or a handoff, never both.
sealed class const PromptStamp();

/// The prompt ran [invocation].
final class const PromptStampCommand({required final CommandInvocation invocation}) implements PromptStamp;

/// The prompt is one of the two messages of a session send.
final class const PromptStampHandoff({required final MessageHandoff handoff}) implements PromptStamp;
