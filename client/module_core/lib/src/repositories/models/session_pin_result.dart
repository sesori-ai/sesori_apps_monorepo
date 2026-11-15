import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const SessionPinResult();

/// The bridge pinned or unpinned the session, which now reads as [session].
final class const SessionPinUpdated({required final Session session}) extends SessionPinResult;

/// The bridge predates pinning, so it cannot pin any session.
final class const SessionPinUnsupported() extends SessionPinResult;

final class const SessionPinFailure({required final ApiError error}) extends SessionPinResult;
