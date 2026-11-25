/// How one squash merge pinned to a head ended (spec §7).
sealed class const PullRequestMergeOutcome();

/// GitHub merged the accepted head. [labelError] is why the
/// `automatically-merged` label could not be added, when it could not.
final class const PullRequestMerged({required final Object? labelError}) extends PullRequestMergeOutcome;

/// The PR's head is no longer the accepted one; the next poll reassesses it.
/// [actualHeadSha] is null when GitHub only answered 409.
final class const PullRequestMergeHeadChanged({required final String? actualHeadSha}) extends PullRequestMergeOutcome;

/// GitHub refused the merge, for example for a missing required review.
/// [cause] is the failed `gh` call, or null when GitHub answered without
/// merging.
final class const PullRequestMergeRejected({required final String reason, required final Object? cause})
    extends PullRequestMergeOutcome;

/// The merge call gave no usable answer and the follow-up read could not
/// prove the accepted head merged.
final class const PullRequestMergeOutcomeUnknown({required final String detail, required final Object cause})
    extends PullRequestMergeOutcome;
