import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const SessionPageResult();

final class const SessionPageLoaded({required final SessionPageResponse page}) extends SessionPageResult;

/// The bridge predates `/sessions/page`, so the caller lists every session of
/// every project instead.
final class const SessionPageUnsupported() extends SessionPageResult;

final class const SessionPageFailure({required final ApiError error}) extends SessionPageResult;
