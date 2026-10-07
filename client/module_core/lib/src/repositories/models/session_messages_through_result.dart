import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const SessionMessagesThroughResult();

/// Every message in the requested range, with the cursor and user count below
/// it.
final class const SessionMessagesThroughAvailable({
  required final List<MessageWithParts> messages,
  required final int? olderMessagesCursor,
  required final int? userMessagesBefore,
}) extends SessionMessagesThroughResult;

/// The bridge predates the load-through route, so asking again cannot succeed.
final class const SessionMessagesThroughUnsupported() extends SessionMessagesThroughResult;

final class const SessionMessagesThroughFailure({required final ApiError error}) extends SessionMessagesThroughResult;
