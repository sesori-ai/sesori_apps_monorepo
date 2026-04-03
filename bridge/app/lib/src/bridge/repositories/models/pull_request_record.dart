class PullRequestRecord {
  final String projectId;
  final int prNumber;
  final String branchName;
  final String url;
  final String title;
  final String state;
  final String mergeableStatus;
  final String reviewDecision;
  final String checkStatus;
  final int lastCheckedAt;
  final int createdAt;

  const PullRequestRecord({
    required this.projectId,
    required this.prNumber,
    required this.branchName,
    required this.url,
    required this.title,
    required this.state,
    required this.mergeableStatus,
    required this.reviewDecision,
    required this.checkStatus,
    required this.lastCheckedAt,
    required this.createdAt,
  });
}
