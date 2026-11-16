import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

/// How the bridge answered a fork.
sealed class const SessionForkResult();

/// The bridge made [session], the fork.
final class const SessionForked({required final Session session}) extends SessionForkResult;

/// A fork after the latest finished turn found none: the session has not
/// finished a turn yet.
final class const SessionForkNothingToFork() extends SessionForkResult;

/// The session cannot be forked there. [reason] is the harness's
/// explanation, safe to show, or null when it gave none.
final class const SessionForkUnavailable({required final String? reason}) extends SessionForkResult;

/// An archived session's worktree was removed and nothing kept where it
/// stood, so only a new worktree from its base branch can hold the fork.
final class const SessionForkWorktreeBranchMissing() extends SessionForkResult;

/// The bridge refused the fork and nothing changed. [reason] is its
/// explanation, safe to show, or null when it gave none.
final class const SessionForkRejected({required final String? reason}) extends SessionForkResult;

/// The answer never arrived or proves nothing, so the fork may exist.
final class const SessionForkFailed({required final ApiError error}) extends SessionForkResult;
