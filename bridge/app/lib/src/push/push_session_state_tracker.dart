import "dart:collection";

import "package:sesori_shared/sesori_shared.dart";

class PushSessionStateTracker {
  final Map<String, _SessionState> _sessions = {};
  final Map<String, String> _messageRoles = {};
  final Map<String, String> _permissionRequestToSession = {};

  PushSessionStateTracker();

  void handleEvent(SesoriSseEvent event) {
    switch (event) {
      case SesoriSessionCreated(:final info):
        _upsertSession(info);
      case SesoriSessionUpdated(:final info):
        _upsertSession(info);
      case SesoriSessionDeleted(:final info):
        _deleteSession(info.id);
      case SesoriSessionStatus(:final sessionID, :final status):
        switch (status) {
          case SessionStatusIdle():
            final sessionState = _sessions[sessionID];
            if (sessionState != null) {
              sessionState.status = null;
            }
          case SessionStatusBusy():
          case SessionStatusRetry():
            final sessionState = _stateForWrite(sessionID);
            sessionState.status = status;
            sessionState.previouslyBusy = true;
        }
      case SesoriMessageUpdated(:final info):
        _messageRoles[info.id] = info.role;
      case SesoriMessageRemoved(:final messageID):
        _messageRoles.remove(messageID);
      case SesoriMessagePartUpdated(:final part):
        _handleMessagePartUpdated(part);
      case SesoriQuestionAsked(:final sessionID):
        _stateForWrite(sessionID).hasPendingQuestion = true;
      case SesoriQuestionReplied(:final sessionID):
        final sessionState = _sessions[sessionID];
        if (sessionState != null) {
          sessionState.hasPendingQuestion = false;
        }
      case SesoriQuestionRejected(:final sessionID):
        final sessionState = _sessions[sessionID];
        if (sessionState != null) {
          sessionState.hasPendingQuestion = false;
        }
      case SesoriPermissionAsked(:final requestID, :final sessionID):
        _permissionRequestToSession[requestID] = sessionID;
        _stateForWrite(sessionID).hasPendingPermission = true;
      case SesoriPermissionReplied(:final requestID):
        final sessionID = _permissionRequestToSession.remove(requestID);
        if (sessionID != null) {
          final sessionState = _sessions[sessionID];
          if (sessionState != null) {
            sessionState.hasPendingPermission = false;
          }
        }
      default:
        break;
    }
  }

  bool isSessionGroupFullyIdle(String sessionId) {
    final queue = Queue<String>()..add(sessionId);
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final currentId = queue.removeFirst();
      if (!visited.add(currentId)) {
        continue;
      }

      final sessionState = _sessions[currentId];
      if (sessionState == null) {
        continue;
      }

      if (sessionState.status != null) {
        return false;
      }

      queue.addAll(sessionState.childIds);
    }

    return true;
  }

  /// True if [sessionId] or any of its descendants has a pending
  /// question or permission.
  bool hasPendingInteraction(String sessionId) {
    final queue = Queue<String>()..add(sessionId);
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final currentId = queue.removeFirst();
      if (!visited.add(currentId)) {
        continue;
      }

      final sessionState = _sessions[currentId];
      if (sessionState == null) {
        continue;
      }

      if (sessionState.hasPendingQuestion || sessionState.hasPendingPermission) {
        return true;
      }

      queue.addAll(sessionState.childIds);
    }

    return false;
  }

  bool wasPreviouslyBusy(String sessionId) {
    return _sessions[sessionId]?.previouslyBusy ?? false;
  }

  String? getSessionTitle(String sessionId) {
    return _sessions[sessionId]?.title;
  }

  String? getLatestAssistantText(String sessionId) {
    return _sessions[sessionId]?.latestAssistantText;
  }

  String resolveRootSessionId(String sessionId) {
    var current = sessionId;
    final visited = <String>{};

    while (true) {
      if (!visited.add(current)) {
        return current;
      }

      final parentId = _sessions[current]?.parentId;
      if (parentId == null) {
        return current;
      }

      if (!_sessions.containsKey(parentId)) {
        return current;
      }

      current = parentId;
    }
  }

  void reset() {
    _sessions.clear();
    _messageRoles.clear();
    _permissionRequestToSession.clear();
  }

  void _upsertSession(Session session) {
    final sessionId = session.id;
    final sessionState = _stateForWrite(sessionId);
    final prevParentId = sessionState.parentId;
    final nextParentId = session.parentID;

    if (prevParentId != null && prevParentId != nextParentId) {
      _sessions[prevParentId]?.childIds.remove(sessionId);
    }

    sessionState.parentId = nextParentId;

    if (nextParentId != null) {
      final parentState = _sessions[nextParentId];
      if (parentState != null) {
        parentState.childIds.add(sessionId);
      }
    }

    sessionState.title = session.title;

    _rebuildChildLinksForParent(sessionId);
  }

  void _deleteSession(String sessionId) {
    _sessions.remove(sessionId);

    for (final sessionState in _sessions.values) {
      sessionState.childIds.remove(sessionId);
      if (sessionState.parentId == sessionId) {
        sessionState.parentId = null;
      }
    }

    _permissionRequestToSession.removeWhere((_, value) => value == sessionId);
  }

  void _handleMessagePartUpdated(MessagePart part) {
    if (part.type != "text") {
      return;
    }

    if (_messageRoles[part.messageID] != "assistant") {
      return;
    }

    _stateForWrite(part.sessionID).latestAssistantText = part.text ?? "";
  }

  _SessionState _stateForWrite(String sessionId) {
    return _sessions.putIfAbsent(sessionId, _SessionState.new);
  }

  void _rebuildChildLinksForParent(String parentId) {
    final parentState = _sessions[parentId];
    if (parentState == null) {
      return;
    }

    parentState.childIds.removeWhere((childId) => _sessions[childId]?.parentId != parentId);
    for (final entry in _sessions.entries) {
      if (entry.value.parentId == parentId) {
        parentState.childIds.add(entry.key);
      }
    }
  }
}

class _SessionState {
  String? parentId;
  String? title;
  SessionStatus? status;
  bool previouslyBusy = false;
  final Set<String> childIds = <String>{};
  String? latestAssistantText;
  bool hasPendingQuestion = false;
  bool hasPendingPermission = false;
}
