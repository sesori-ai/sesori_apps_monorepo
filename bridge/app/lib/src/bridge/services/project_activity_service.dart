import "dart:async";
import "dart:math" show max;

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/project_activity.dart";
import "../repositories/project_repository.dart";

class ProjectActivityService {
  ProjectActivityService({required ProjectRepository projectRepository, required int Function() now})
    : _projectRepository = projectRepository,
      _now = now;

  final ProjectRepository _projectRepository;
  final int Function() _now;
  final StreamController<ProjectActivityChange> _changes = StreamController<ProjectActivityChange>.broadcast();

  Future<void> _writeTail = Future<void>.value();
  bool _disposing = false;

  Stream<ProjectActivityChange> get changes => _changes.stream;

  Future<List<Project>> getProjects() {
    return _projectRepository.getProjects();
  }

  Future<Project> openProject({required String path}) async {
    final target = await _projectRepository.resolveProjectOpenTarget(path: path);
    return _serialize(() async {
      final result = await _projectRepository.persistOpenedProject(
        target: target,
        observedAt: _now(),
      );
      if (result.updatedAtAdvanced) {
        _emit(
          projectId: result.committedTarget.projectId,
          updatedAt: result.committedActivity.updatedAt,
        );
      }
      return _projectRepository.mapOpenedProject(
        target: result.committedTarget,
        committedActivity: result.committedActivity,
      );
    });
  }

  Future<void> handleEvent(SesoriSseEvent event) async {
    switch (event) {
      case SesoriMessageUpdated(:final info):
        final int? occurredAt;
        switch (info) {
          case MessageUser(:final time):
            occurredAt = time?.created ?? _now();
          case MessageAssistant(:final time):
            occurredAt = time?.completed;
            if (occurredAt == null) return;
          case MessageError(:final time):
            occurredAt = time?.completed ?? time?.created ?? _now();
        }
        await _touchStoredSession(sessionId: info.sessionID, occurredAt: occurredAt);
      case SesoriQuestionAsked(:final sessionID, :final displaySessionId) ||
          SesoriQuestionReplied(:final sessionID, :final displaySessionId) ||
          SesoriQuestionRejected(:final sessionID, :final displaySessionId) ||
          SesoriPermissionAsked(:final sessionID, :final displaySessionId) ||
          SesoriPermissionReplied(:final sessionID, :final displaySessionId):
        if (displaySessionId != null) return;
        await _touchStoredSession(sessionId: sessionID, occurredAt: _now());
      default:
        return;
    }
  }

  Future<void> _touchStoredSession({required String sessionId, required int occurredAt}) {
    return _serialize(() async {
      final stored = await _projectRepository.getStoredSessionActivity(sessionId: sessionId);
      if (stored == null) return;
      final activity = ProjectActivity(
        createdAt: stored.activity.createdAt,
        updatedAt: max(stored.activity.updatedAt, occurredAt),
      );
      if (activity == stored.activity) return;
      await _projectRepository.writeActivity(projectId: stored.projectId, activity: activity);
      if (activity.updatedAt > stored.activity.updatedAt) {
        _emit(projectId: stored.projectId, updatedAt: activity.updatedAt);
      }
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    if (_disposing) {
      return Future<T>.error(StateError("ProjectActivityService is disposed"));
    }
    final result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  void _emit({required String projectId, required int updatedAt}) {
    _changes.add(ProjectActivityChange(projectId: projectId, updatedAt: updatedAt));
  }

  Future<void> dispose() async {
    if (_disposing) return;
    _disposing = true;
    await _writeTail;
    await _changes.close();
  }
}
