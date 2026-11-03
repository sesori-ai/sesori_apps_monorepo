import "../../repositories/models/session_cleanup_rejection.dart";
import "session_cleanup_outcome.dart";

/// How a request to delete a session ended.
sealed class const SessionDeleteResult();

final class const SessionDeleted({required final SessionCleanupOutcome outcome}) extends SessionDeleteResult;

/// The bridge refused the cleanup; deleting anyway can still be offered.
final class const SessionDeleteRejected({required final SessionCleanupRejection rejection}) extends SessionDeleteResult;

final class const SessionDeleteFailed() extends SessionDeleteResult;
