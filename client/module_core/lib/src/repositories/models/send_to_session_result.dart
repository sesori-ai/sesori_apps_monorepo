import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

/// How a send of one session into another ended.
sealed class const SendToSessionResult();

/// The target accepted the handoff, with the source's summary.
final class const SendToSessionSent() extends SendToSessionResult;

/// The bridge did not send, for [code]. [message] is the harness's own
/// explanation, safe to show, when it gave one.
final class const SendToSessionRefused({
  required final SendToSessionErrorCode code,
  required final String? message,
}) extends SendToSessionResult;

/// The request failed before the bridge could send, or with an answer that
/// is not a refusal.
final class const SendToSessionFailed({required final ApiError error}) extends SendToSessionResult;

/// The bridge predates sending sessions.
final class const SendToSessionUnsupported() extends SendToSessionResult;

/// The answer never arrived: the request timed out or the connection dropped
/// after it went out. The bridge finishes the send regardless.
final class const SendToSessionUnconfirmed({required final ApiError error}) extends SendToSessionResult;
