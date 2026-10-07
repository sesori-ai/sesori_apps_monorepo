import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const SessionPromptSearchResult();

/// Every prompt in the session's history that holds the query, oldest first.
final class const SessionPromptSearchAvailable({
  required final List<SessionPromptSearchMatch> matches,
}) extends SessionPromptSearchResult;

/// The bridge predates prompt search.
final class const SessionPromptSearchUnsupported() extends SessionPromptSearchResult;

final class const SessionPromptSearchFailure({required final ApiError error}) extends SessionPromptSearchResult;
