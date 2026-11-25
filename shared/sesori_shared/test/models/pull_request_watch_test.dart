import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  Map<String, dynamic> watchJson({required Map<String, dynamic> status}) => {
    "repository": "sesori/app",
    "number": 7,
    "title": "Fix the build",
    "url": "https://github.com/sesori/app/pull/7",
    "autoMerge": false,
    "status": status,
  };

  test("an older bridge's session watches no PRs", () {
    final session = Session.fromJson(const {
      "id": "ses_1",
      "projectID": "proj_1",
      "directory": "/tmp",
      "parentID": null,
      "title": null,
      "time": null,
    });

    expect(session.pullRequestWatches, isEmpty);
  });

  test("a watch round trips with its status", () {
    const watch = SessionPullRequestWatch(
      repository: "sesori/app",
      number: 7,
      title: "Fix the build",
      url: "https://github.com/sesori/app/pull/7",
      autoMerge: true,
      status: PullRequestWatchStatus.merged(mergedAt: 1764000000000),
    );

    expect(SessionPullRequestWatch.fromJson(watch.toJson()), watch);
  });

  test("a status kind or reason from a newer bridge reads as unknown", () {
    expect(
      SessionPullRequestWatch.fromJson(watchJson(status: {"kind": "queued"})).status,
      const PullRequestWatchStatus.unknown(),
    );
    expect(
      SessionPullRequestWatch.fromJson(
        watchJson(
          status: {
            "kind": "needsYou",
            "reasons": ["conflict", "securityAlert"],
          },
        ),
      ).status,
      const PullRequestWatchStatus.needsYou(reasons: [PullRequestWatchNeed.conflict, PullRequestWatchNeed.unknown]),
    );
  });
}
