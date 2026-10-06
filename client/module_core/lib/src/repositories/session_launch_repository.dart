import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/storage/session_launch_storage.dart";
import "../errors/remote_failure_reason.dart";
import "../foundation/models/composer/new_session_submission_snapshot.dart";
import "../foundation/models/composer/prompt_send_failure.dart";
import "../foundation/models/composer/queued_session_submission.dart";
import "../foundation/models/session_launch/launch_follow_up.dart";
import "../foundation/models/session_launch/session_launch.dart";
import "../foundation/models/session_launch/session_launch_handoff.dart";
import "../foundation/models/session_launch/session_launch_outcome.dart";

/// The sole publisher of session launches.
///
/// There is no `complete`: after every transition the entry is kept only while
/// it still owes something — a session while pending, the handoff while a
/// first message is held, delivery while a follow-up is queued, sending or
/// failed — and removed the moment it owes nothing.
@lazySingleton
class SessionLaunchRepository({required final SessionLaunchStorage _storage}) {
  final StreamController<SessionLaunchOutcome> _outcomes = StreamController<SessionLaunchOutcome>.broadcast();

  /// Every launch a transition produced, including one it then removed, so a
  /// watcher sees the last follow-ups an entry held before it went.
  final StreamController<SessionLaunch> _changes = StreamController<SessionLaunch>.broadcast();

  /// How each launch's creation ended, published once per launch.
  Stream<SessionLaunchOutcome> get outcomes => _outcomes.stream;

  /// The follow-ups of the launch that created [sessionId], now and after
  /// every change; empty when there is none. Watch only after [takeHandoff]:
  /// from then on an accepted follow-up appears in exactly one emission, for
  /// the watching session screen to park, whereas before it the handoff still
  /// holds accepted ones and every emission repeats them.
  Stream<List<LaunchFollowUp>> watchForSession({required String sessionId}) => Rx.defer(
    () => _changes.stream
        .where((launch) => _sessionOf(launch: launch)?.id == sessionId)
        .map((launch) => launch.followUps)
        .startWith(
          _storage.readAll().where((launch) => _sessionOf(launch: launch)?.id == sessionId).firstOrNull?.followUps ??
              const [],
        ),
  );

  void start({
    required String launchId,
    required String projectId,
    required String pluginId,
    required DateTime startedAt,
    required NewSessionSubmissionSnapshot submission,
  }) {
    _put(
      launch: SessionLaunch.pending(
        launchId: launchId,
        projectId: projectId,
        pluginId: pluginId,
        startedAt: startedAt,
        followUpIds: const {},
        followUps: const [],
        submission: submission,
      ),
    );
  }

  /// Queues a message sent after the first one, behind any already queued.
  void addFollowUp({required String launchId, required QueuedSessionSubmission submission}) {
    final launch = _storage.read(launchId: launchId);
    if (launch == null) return;
    _put(
      launch: launch.copyWith(
        followUpIds: {...launch.followUpIds, submission.promptId},
        followUps: [
          ...launch.followUps,
          LaunchFollowUp.queued(submission: submission),
        ],
      ),
    );
  }

  /// Marks the next follow-up of a created launch as sending and returns it
  /// with its session. Null while the session does not exist yet, when
  /// nothing is queued, or while the one ahead is still sending or failed.
  ({String sessionId, QueuedSessionSubmission submission})? beginFollowUp({required String launchId}) {
    final launch = _storage.read(launchId: launchId);
    if (launch == null) return null;
    final session = _sessionOf(launch: launch);
    if (session == null) return null;
    final index = launch.followUps.indexWhere((followUp) => followUp is! AcceptedLaunchFollowUp);
    if (index < 0) return null;
    if (launch.followUps[index] case QueuedLaunchFollowUp(:final submission)) {
      _replaceFollowUp(
        launch: launch,
        index: index,
        followUp: LaunchFollowUp.sending(submission: submission),
      );
      return (sessionId: session.id, submission: submission);
    }
    return null;
  }

  /// Records the bridge's acceptance. While the handoff is owed, the accepted
  /// follow-up goes with it; after that it goes to whichever session screen is
  /// watching and leaves the launch.
  void followUpAccepted({required String launchId, required String promptId}) {
    final launch = _storage.read(launchId: launchId);
    if (launch == null) return;
    final index = _indexOf(launch: launch, promptId: promptId);
    if (index < 0) return;
    final accepted = LaunchFollowUp.accepted(submission: launch.followUps[index].submission);
    if (launch is CreatedSessionLaunch) {
      _replaceFollowUp(launch: launch, index: index, followUp: accepted);
      return;
    }
    final followUps = [...launch.followUps];
    _changes.add(launch.copyWith(followUps: followUps..[index] = accepted));
    _put(launch: launch.copyWith(followUps: [...followUps]..removeAt(index)));
  }

  /// Returns whether the failure was recorded; a follow-up the bridge settled
  /// meanwhile is gone and did not fail.
  bool followUpFailed({required String launchId, required String promptId, required PromptSendFailure failure}) {
    final launch = _storage.read(launchId: launchId);
    if (launch == null) return false;
    final index = _indexOf(launch: launch, promptId: promptId);
    if (index < 0) return false;
    _replaceFollowUp(
      launch: launch,
      index: index,
      followUp: LaunchFollowUp.failed(submission: launch.followUps[index].submission, failure: failure),
    );
    return true;
  }

  /// Puts a failed follow-up back in its place as queued, unchanged, so its
  /// resend carries the same promptId. Returns its launch, or null when no
  /// launch holds it as failed.
  String? retryFollowUp({required String promptId}) {
    for (final launch in _storage.readAll().toList()) {
      final index = _indexOf(launch: launch, promptId: promptId);
      if (index < 0) continue;
      if (launch.followUps[index] case FailedLaunchFollowUp(:final submission)) {
        _replaceFollowUp(
          launch: launch,
          index: index,
          followUp: LaunchFollowUp.queued(submission: submission),
        );
        return launch.launchId;
      }
    }
    return null;
  }

  /// Removes a queued or failed follow-up. Returns its launch, or null when
  /// no launch holds it unsent.
  String? cancelFollowUp({required String promptId}) {
    for (final launch in _storage.readAll().toList()) {
      final index = _indexOf(launch: launch, promptId: promptId);
      if (index < 0) continue;
      if (launch.followUps[index] case QueuedLaunchFollowUp() || FailedLaunchFollowUp()) {
        _put(launch: launch.copyWith(followUps: [...launch.followUps]..removeAt(index)));
        return launch.launchId;
      }
    }
    return null;
  }

  /// Drops a follow-up the bridge has terminally accounted for, in whatever
  /// state it is in, so its send outcome arriving later changes nothing.
  /// Returns its launch, or null when no launch holds it.
  String? settleFollowUp({required String promptId}) {
    for (final launch in _storage.readAll().toList()) {
      final index = _indexOf(launch: launch, promptId: promptId);
      if (index < 0) continue;
      _put(launch: launch.copyWith(followUps: [...launch.followUps]..removeAt(index)));
      return launch.launchId;
    }
    return null;
  }

  /// Records the session the bridge created. A launch whose payload was
  /// already released goes straight to reconciling, which owes only its
  /// follow-ups.
  void promote({required String launchId, required Session session}) {
    switch (_storage.read(launchId: launchId)) {
      case PendingSessionLaunch(
        :final projectId,
        :final pluginId,
        :final startedAt,
        :final followUpIds,
        :final followUps,
        :final submission,
      ):
        _put(
          launch: SessionLaunch.created(
            launchId: launchId,
            projectId: projectId,
            pluginId: pluginId,
            startedAt: startedAt,
            followUpIds: followUpIds,
            followUps: followUps,
            session: session,
            submission: submission,
          ),
        );
      case ReleasedPendingSessionLaunch(
        :final projectId,
        :final pluginId,
        :final startedAt,
        :final followUpIds,
        :final followUps,
      ):
        _put(
          launch: SessionLaunch.reconciling(
            launchId: launchId,
            projectId: projectId,
            pluginId: pluginId,
            startedAt: startedAt,
            followUpIds: followUpIds,
            followUps: followUps,
            session: session,
          ),
        );
      case CreatedSessionLaunch() || ReconcilingSessionLaunch() || null:
        return;
    }
    _outcomes.add(SessionLaunchOutcome.succeeded(launchId: launchId, session: session));
  }

  /// Ends a launch whose creation failed. The failure goes to the composer
  /// when it still holds the payload, and otherwise to whoever reports
  /// failures after the user has left.
  void fail({required String launchId, required RemoteFailureReason reason}) {
    final outcome = switch (_storage.read(launchId: launchId)) {
      PendingSessionLaunch() => SessionLaunchOutcome.failedWhileComposing(launchId: launchId, reason: reason),
      ReleasedPendingSessionLaunch(:final projectId) => SessionLaunchOutcome.failedAfterLeaving(
        launchId: launchId,
        projectId: projectId,
        reason: reason,
      ),
      CreatedSessionLaunch() || ReconcilingSessionLaunch() || null => null,
    };
    if (outcome == null) return;
    _storage.clear(launchId: launchId);
    _outcomes.add(outcome);
  }

  /// Hands the first message of the created launch for [sessionId] to the
  /// session screen, once, with the follow-ups accepted so far. Null for any
  /// other session, or while the launch is still pending.
  SessionLaunchHandoff? takeHandoff({required String sessionId}) {
    final launch = _storage
        .readAll()
        .whereType<CreatedSessionLaunch>()
        .where((launch) => launch.session.id == sessionId)
        .firstOrNull;
    if (launch == null) return null;
    _put(launch: _reconciling(launch: launch));
    return SessionLaunchHandoff(
      submission: launch.submission,
      pluginId: launch.pluginId,
      startedAt: launch.startedAt,
      followUpIds: launch.followUpIds,
      acceptedFollowUps: [
        for (final followUp in launch.followUps)
          if (followUp case AcceptedLaunchFollowUp(:final submission)) submission,
      ],
    );
  }

  /// Discards the handoff because the composing route will not pass it on.
  /// Defined on a pending launch too: leaving mid-create drops the payload at
  /// once, and the later [promote] finds nothing to hand over.
  void releaseHandoff({required String launchId}) {
    switch (_storage.read(launchId: launchId)) {
      case PendingSessionLaunch(
        :final projectId,
        :final pluginId,
        :final startedAt,
        :final followUpIds,
        :final followUps,
      ):
        _put(
          launch: SessionLaunch.pendingReleased(
            launchId: launchId,
            projectId: projectId,
            pluginId: pluginId,
            startedAt: startedAt,
            followUpIds: followUpIds,
            followUps: followUps,
          ),
        );
      case final CreatedSessionLaunch launch:
        _put(launch: _reconciling(launch: launch));
      case ReleasedPendingSessionLaunch() || ReconcilingSessionLaunch() || null:
        break;
    }
  }

  /// A created launch without its handoff. Accepted follow-ups leave with the
  /// handoff: the taker parks them, and after a release nothing ever drew them.
  static ReconcilingSessionLaunch _reconciling({required CreatedSessionLaunch launch}) => ReconcilingSessionLaunch(
    launchId: launch.launchId,
    projectId: launch.projectId,
    pluginId: launch.pluginId,
    startedAt: launch.startedAt,
    followUpIds: launch.followUpIds,
    followUps: [
      for (final followUp in launch.followUps)
        if (followUp is! AcceptedLaunchFollowUp) followUp,
    ],
    session: launch.session,
  );

  static Session? _sessionOf({required SessionLaunch launch}) => switch (launch) {
    CreatedSessionLaunch(:final session) || ReconcilingSessionLaunch(:final session) => session,
    PendingSessionLaunch() || ReleasedPendingSessionLaunch() => null,
  };

  static int _indexOf({required SessionLaunch launch, required String promptId}) =>
      launch.followUps.indexWhere((followUp) => followUp.submission.promptId == promptId);

  void _replaceFollowUp({required SessionLaunch launch, required int index, required LaunchFollowUp followUp}) {
    _put(launch: launch.copyWith(followUps: [...launch.followUps]..[index] = followUp));
  }

  void _put({required SessionLaunch launch}) {
    final owesSomething = switch (launch) {
      PendingSessionLaunch() || ReleasedPendingSessionLaunch() || CreatedSessionLaunch() => true,
      ReconcilingSessionLaunch(:final followUps) => followUps.isNotEmpty,
    };
    if (owesSomething) {
      _storage.write(launch: launch);
    } else {
      _storage.clear(launchId: launch.launchId);
    }
    _changes.add(launch);
  }
}
