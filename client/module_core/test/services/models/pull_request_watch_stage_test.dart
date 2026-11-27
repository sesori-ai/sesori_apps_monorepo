import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

PullRequestWatchStage _stageOf(List<PullRequestWatchNeed> reasons) =>
    PullRequestWatchStage.of(status: PullRequestWatchStatus.needsYou(reasons: reasons));

void main() {
  test("ready with no auto-merge is the only reason to merge", () {
    expect(_stageOf([PullRequestWatchNeed.readyWithoutAutoMerge]), PullRequestWatchStage.toMerge);
    expect(
      _stageOf([PullRequestWatchNeed.unknown, PullRequestWatchNeed.readyWithoutAutoMerge]),
      PullRequestWatchStage.toMerge,
    );
  });

  test("a reason the agent handles wins over ready to merge", () {
    for (final need in [
      PullRequestWatchNeed.ciFailing,
      PullRequestWatchNeed.conflict,
      PullRequestWatchNeed.newReviewComments,
    ]) {
      expect(_stageOf([need]), PullRequestWatchStage.agentOnIt);
      expect(_stageOf([need, PullRequestWatchNeed.readyWithoutAutoMerge]), PullRequestWatchStage.agentOnIt);
    }
  });

  test("only reasons this build does not know wait", () {
    expect(_stageOf([PullRequestWatchNeed.unknown]), PullRequestWatchStage.waiting);
  });

  test("the other statuses map to their own stage", () {
    expect(PullRequestWatchStage.of(status: const PullRequestWatchStatus.waiting()), PullRequestWatchStage.waiting);
    expect(PullRequestWatchStage.of(status: const PullRequestWatchStatus.unknown()), PullRequestWatchStage.waiting);
    expect(
      PullRequestWatchStage.of(status: const PullRequestWatchStatus.ready()),
      PullRequestWatchStage.mergesAutomatically,
    );
    expect(
      PullRequestWatchStage.of(status: const PullRequestWatchStatus.merged(mergedAt: 1)),
      PullRequestWatchStage.mergedToday,
    );
  });
}
