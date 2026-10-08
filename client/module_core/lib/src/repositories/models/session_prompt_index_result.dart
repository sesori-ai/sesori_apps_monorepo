import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const SessionPromptIndexResult();

/// Every prompt in the session's history, oldest first.
final class const SessionPromptIndexAvailable({
  required final List<SessionPromptIndexEntry> entries,
}) extends SessionPromptIndexResult;

/// The bridge predates the prompt index route. The cubit still asks after each
/// refresh, which costs one 404 and picks up a bridge updated meanwhile.
final class const SessionPromptIndexUnsupported() extends SessionPromptIndexResult;

final class const SessionPromptIndexFailure({required final ApiError error}) extends SessionPromptIndexResult;
