import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

PullRequestWatchListItem _item({
  required String repository,
  required int number,
  required PullRequestWatchStatus status,
  String sessionId = "session-1",
}) => PullRequestWatchListItem(
  sessionId: sessionId,
  sessionTitle: null,
  projectId: "project-1",
  watch: SessionPullRequestWatch(
    repository: repository,
    number: number,
    title: "Fixture $number",
    url: "https://github.com/$repository/pull/$number",
    autoMerge: false,
    status: status,
  ),
);

const _agentOnIt = PullRequestWatchStatus.needsYou(reasons: [PullRequestWatchNeed.conflict]);
const _toMerge = PullRequestWatchStatus.needsYou(reasons: [PullRequestWatchNeed.readyWithoutAutoMerge]);
const _waiting = PullRequestWatchStatus.waiting();
const _ready = PullRequestWatchStatus.ready();

List<String> _shape(List<PullRequestWatchSection> sections) => [
  for (final section in sections)
    "${section.group.name}: ${section.watches.map((item) => item.watch.number).join(", ")}",
];

void main() {
  test("groups by status, open ones by repository and number, merged ones newest first", () {
    final sections = arrangePullRequestWatches(
      watches: [
        _item(repository: "acme/b", number: 1, status: _waiting),
        _item(repository: "acme/a", number: 7, status: _waiting),
        _item(repository: "acme/a", number: 3, status: const PullRequestWatchStatus.unknown()),
        _item(repository: "acme/a", number: 4, status: const PullRequestWatchStatus.merged(mergedAt: 10)),
        _item(repository: "acme/a", number: 5, status: const PullRequestWatchStatus.merged(mergedAt: 20)),
        _item(repository: "acme/a", number: 9, status: _agentOnIt),
        _item(repository: "acme/a", number: 8, status: _ready),
        _item(repository: "acme/a", number: 6, status: _toMerge),
      ],
      sessionId: null,
      shown: null,
    );

    expect(_shape(sections), [
      "toMerge: 6",
      "agentOnIt: 9",
      "waiting: 3, 7, 1",
      "mergesAutomatically: 8",
      "mergedToday: 5, 4",
    ]);
  });

  test("while open, rows keep their place; ended ones leave and new ones join their group's end", () {
    final shown = arrangePullRequestWatches(
      watches: [
        _item(repository: "acme/a", number: 1, status: _agentOnIt),
        _item(repository: "acme/a", number: 2, status: _waiting),
        _item(repository: "acme/a", number: 3, status: _waiting),
      ],
      sessionId: null,
      shown: null,
    );

    final next = arrangePullRequestWatches(
      watches: [
        _item(repository: "acme/a", number: 1, status: _ready),
        _item(repository: "acme/a", number: 3, status: _waiting),
        _item(repository: "acme/a", number: 4, status: _agentOnIt),
        _item(repository: "acme/a", number: 0, status: _waiting),
      ],
      sessionId: null,
      shown: shown,
    );

    expect(_shape(next), [
      "agentOnIt: 1, 4",
      "waiting: 3, 0",
    ]);
    expect(next.first.watches.first.watch.status, _ready);
  });

  test("a session's list holds only that session's watches", () {
    final sections = arrangePullRequestWatches(
      watches: [
        _item(repository: "acme/a", number: 1, status: _waiting),
        _item(repository: "acme/a", number: 2, status: _waiting, sessionId: "session-2"),
      ],
      sessionId: "session-2",
      shown: null,
    );

    expect(_shape(sections), [
      "waiting: 2",
    ]);
  });
}
