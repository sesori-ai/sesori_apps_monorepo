import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/storage/session_launch_storage.dart";
import "../errors/remote_failure_reason.dart";
import "../foundation/models/composer/new_session_submission_snapshot.dart";
import "../foundation/models/session_launch/session_launch.dart";
import "../foundation/models/session_launch/session_launch_handoff.dart";
import "../foundation/models/session_launch/session_launch_outcome.dart";

/// The sole publisher of session launches.
///
/// There is no `complete`: after every transition the entry is kept only while
/// it still owes something — a session while pending, the handoff while a
/// first message is held — and removed the moment it owes nothing.
@lazySingleton
class SessionLaunchRepository({required final SessionLaunchStorage _storage}) {
  final StreamController<SessionLaunchOutcome> _outcomes = StreamController<SessionLaunchOutcome>.broadcast();

  /// How each launch's creation ended, published once per launch.
  Stream<SessionLaunchOutcome> get outcomes => _outcomes.stream;

  void start({
    required String launchId,
    required String projectId,
    required String pluginId,
    required DateTime startedAt,
    required NewSessionSubmissionSnapshot submission,
  }) {
    _storage.write(
      launch: SessionLaunch.pending(
        launchId: launchId,
        projectId: projectId,
        pluginId: pluginId,
        startedAt: startedAt,
        followUpIds: const {},
        submission: submission,
      ),
    );
  }

  /// Records the session the bridge created. A launch whose payload was
  /// already released goes straight to reconciling, which owes nothing here.
  void promote({required String launchId, required Session session}) {
    if (_storage.read(launchId: launchId) case PendingSessionLaunch(
      :final projectId,
      :final pluginId,
      :final startedAt,
      :final followUpIds,
      :final submission,
    )) {
      _put(
        launch: submission == null
            ? SessionLaunch.reconciling(
                launchId: launchId,
                projectId: projectId,
                pluginId: pluginId,
                startedAt: startedAt,
                followUpIds: followUpIds,
                session: session,
              )
            : SessionLaunch.created(
                launchId: launchId,
                projectId: projectId,
                pluginId: pluginId,
                startedAt: startedAt,
                followUpIds: followUpIds,
                session: session,
                submission: submission,
              ),
      );
      _outcomes.add(SessionLaunchOutcome.succeeded(launchId: launchId, session: session));
    }
  }

  /// Ends a launch whose creation failed. The failure goes to the composer
  /// when it still holds the payload, and otherwise to whoever reports
  /// failures after the user has left.
  void fail({required String launchId, required RemoteFailureReason reason}) {
    if (_storage.read(launchId: launchId) case PendingSessionLaunch(:final projectId, :final submission)) {
      _storage.clear(launchId: launchId);
      _outcomes.add(
        submission == null
            ? SessionLaunchOutcome.failedAfterLeaving(launchId: launchId, projectId: projectId, reason: reason)
            : SessionLaunchOutcome.failedWhileComposing(launchId: launchId, reason: reason),
      );
    }
  }

  /// Hands the first message of the created launch for [sessionId] to the
  /// session screen, once. Null for any other session, or while the launch is
  /// still pending.
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
    );
  }

  /// Discards the handoff because the composing route will not pass it on.
  /// Defined on a pending launch too: leaving mid-create drops the payload at
  /// once, and the later [promote] finds nothing to hand over.
  void releaseHandoff({required String launchId}) {
    switch (_storage.read(launchId: launchId)) {
      case final PendingSessionLaunch launch when launch.submission != null:
        _put(launch: launch.copyWith(submission: null));
      case final CreatedSessionLaunch launch:
        _put(launch: _reconciling(launch: launch));
      case PendingSessionLaunch() || ReconcilingSessionLaunch() || null:
        break;
    }
  }

  static ReconcilingSessionLaunch _reconciling({required CreatedSessionLaunch launch}) => ReconcilingSessionLaunch(
    launchId: launch.launchId,
    projectId: launch.projectId,
    pluginId: launch.pluginId,
    startedAt: launch.startedAt,
    followUpIds: launch.followUpIds,
    session: launch.session,
  );

  void _put({required SessionLaunch launch}) {
    final owesSomething = switch (launch) {
      PendingSessionLaunch() || CreatedSessionLaunch() => true,
      ReconcilingSessionLaunch() => false,
    };
    if (owesSomething) {
      _storage.write(launch: launch);
    } else {
      _storage.clear(launchId: launch.launchId);
    }
  }
}
