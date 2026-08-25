import "package:sesori_shared/sesori_shared.dart";

import "../../api/database/tables/pull_requests_table.dart";

PullRequestInfo pullRequestInfoFromDto(PullRequestDto dto) {
  return PullRequestInfo(
    number: dto.prNumber,
    url: dto.url,
    title: dto.title,
    state: dto.state,
    mergeableStatus: dto.mergeableStatus,
    reviewDecision: dto.reviewDecision,
    checkStatus: dto.checkStatus,
  );
}
