import "package:sesori_shared/sesori_shared.dart";

/// What the bridge stamps on the user message that fulfils a prompt it sent.
/// A prompt is a command, a handoff or a notice, never two of them.
sealed class const PromptStamp();

/// The prompt ran [invocation].
final class const PromptStampCommand({required final CommandInvocation invocation}) implements PromptStamp;

/// What marks a prompt the bridge writes itself, as it sends it.
sealed class const BridgePromptMark() implements PromptStamp;

/// The prompt is one of the two messages of a session send.
final class const PromptStampHandoff({required final MessageHandoff handoff}) implements BridgePromptMark;

/// The prompt is a Sesori notice: its echo shows as a Sesori row with only
/// the notice's summary.
final class const PromptStampNotice() implements BridgePromptMark;
