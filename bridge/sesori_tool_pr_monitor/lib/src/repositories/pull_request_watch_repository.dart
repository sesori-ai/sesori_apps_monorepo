import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../models/pull_request_target.dart";
import "models/stored_pull_request_watch.dart";

/// The watches in the group's store: one session record per watching
/// session and PR, keyed by the PR's lowercased `owner/repo#n`. A session's
/// watches are deleted with it.
class PullRequestWatchRepository({required final SesoriToolStore _store}) {
  /// Every stored watch. A record that no longer parses is logged and left
  /// out.
  Future<List<({String sessionId, StoredPullRequestWatch watch})>> loadAll() async {
    final records = await _store.listSessionRecords();
    return [
      for (final record in records)
        if (_parse(sessionId: record.sessionId, key: record.key, value: record.value) case final watch?)
          (sessionId: record.sessionId, watch: watch),
    ];
  }

  /// Writes [watch], replacing [sessionId]'s earlier record of the PR. The
  /// session must be stored.
  Future<void> save({required String sessionId, required StoredPullRequestWatch watch}) => _store.putSessionRecord(
    sessionId: sessionId,
    key: PullRequestTarget(owner: watch.owner, repo: watch.repo, number: watch.number).registryKey,
    value: watch.toJson(),
  );

  /// Deletes [sessionId]'s watch of [target]; true when it existed.
  Future<bool> delete({required String sessionId, required PullRequestTarget target}) =>
      _store.deleteSessionRecord(sessionId: sessionId, key: target.registryKey);

  StoredPullRequestWatch? _parse({
    required String sessionId,
    required String key,
    required Map<String, Object?> value,
  }) {
    try {
      return StoredPullRequestWatch.fromJson(value);
    } on Object catch (error, stackTrace) {
      Log.w("PR monitor: skipped unreadable watch $key of session $sessionId", error, stackTrace);
      return null;
    }
  }
}
