import "package:sesori_shared/sesori_shared.dart";

class PushSessionStateTracker {
  final Map<String, SessionStatus> _sessionStatuses = {};
  final Map<String, String?> _sessionParentIds = {};
  final Map<String, Set<String>> _sessionChildren = {};
  final Map<String, String> _sessionTitles = {};
  final Map<String, String> _messageRoles = {};
  final Map<String, String> _latestAssistantText = {};
  final Set<String> _pendingQuestions = {};
  final Set<String> _pendingPermissions = {};
  final Map<String, String> _permissionRequestToSession = {};
  final Set<String> _previouslyBusy = {};

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
            _sessionStatuses.remove(sessionID);
          case SessionStatusBusy():
          case SessionStatusRetry():
            _sessionStatuses[sessionID] = status;
            _previouslyBusy.add(sessionID);
        }
      case SesoriMessageUpdated(:final info):
        _messageRoles[info.id] = info.role;
      case SesoriMessageRemoved(:final messageID):
        _messageRoles.remove(messageID);
      case SesoriMessagePartUpdated(:final part):
        _handleMessagePartUpdated(part);
      case SesoriQuestionAsked(:final sessionID):
        _pendingQuestions.add(sessionID);
      case SesoriQuestionReplied(:final sessionID):
        _pendingQuestions.remove(sessionID);
      case SesoriQuestionRejected(:final sessionID):
        _pendingQuestions.remove(sessionID);
      case SesoriPermissionAsked(:final requestID, :final sessionID):
        _permissionRequestToSession[requestID] = sessionID;
        _pendingPermissions.add(sessionID);
      case SesoriPermissionReplied(:final requestID):
        final sessionID = _permissionRequestToSession.remove(requestID);
        if (sessionID != null) {
          _pendingPermissions.remove(sessionID);
        }
      default:
        break;
    }
  }

  bool isSessionGroupFullyIdle(String sessionId) {
    if (_sessionStatuses.containsKey(sessionId)) {
      return false;
    }
    final children = _sessionChildren[sessionId];
    if (children == null || children.isEmpty) {
      return true;
    }
    for (final childId in children) {
      if (_sessionStatuses.containsKey(childId)) {
        return false;
      }
    }
    return true;
  }

  /// True if [sessionId] or any of its direct children has a pending
  /// question or permission.
  bool hasPendingInteraction(String sessionId) {
    if (_pendingQuestions.contains(sessionId) || _pendingPermissions.contains(sessionId)) {
      return true;
    }
    final children = _sessionChildren[sessionId];
    if (children != null) {
      for (final childId in children) {
        if (_pendingQuestions.contains(childId) || _pendingPermissions.contains(childId)) {
          return true;
        }
      }
    }
    return false;
  }

  bool wasPreviouslyBusy(String sessionId) {
    return _previouslyBusy.contains(sessionId);
  }

  String? getSessionTitle(String sessionId) {
    return _sessionTitles[sessionId];
  }

  String? getLatestAssistantText(String sessionId) {
    return _latestAssistantText[sessionId];
  }

  String resolveRootSessionId(String sessionId) {
    var current = sessionId;
    final visited = <String>{};

    while (true) {
      if (!visited.add(current)) {
        return current;
      }

      final parentId = _sessionParentIds[current];
      if (parentId == null) {
        return current;
      }

      if (!_sessionParentIds.containsKey(parentId)) {
        return current;
      }

      current = parentId;
    }
  }

  void reset() {
    _sessionStatuses.clear();
    _sessionParentIds.clear();
    _sessionChildren.clear();
    _sessionTitles.clear();
    _messageRoles.clear();
    _latestAssistantText.clear();
    _pendingQuestions.clear();
    _pendingPermissions.clear();
    _permissionRequestToSession.clear();
    _previouslyBusy.clear();
  }

  void _upsertSession(Session session) {
    final sessionId = session.id;
    final prevParentId = _sessionParentIds[sessionId];
    final nextParentId = session.parentID;

    if (prevParentId != null && prevParentId != nextParentId) {
      final siblings = _sessionChildren[prevParentId];
      siblings?.remove(sessionId);
      if (siblings != null && siblings.isEmpty) {
        _sessionChildren.remove(prevParentId);
      }
    }

    _sessionParentIds[sessionId] = nextParentId;

    if (nextParentId != null) {
      _sessionChildren.putIfAbsent(nextParentId, () => <String>{}).add(sessionId);
    }

    final title = session.title;
    if (title == null) {
      _sessionTitles.remove(sessionId);
    } else {
      _sessionTitles[sessionId] = title;
    }
  }

  void _deleteSession(String sessionId) {
    final parentId = _sessionParentIds.remove(sessionId);
    if (parentId != null) {
      final siblings = _sessionChildren[parentId];
      siblings?.remove(sessionId);
      if (siblings != null && siblings.isEmpty) {
        _sessionChildren.remove(parentId);
      }
    }

    final children = _sessionChildren.remove(sessionId);
    if (children != null) {
      for (final childId in children) {
        _sessionParentIds[childId] = null;
      }
    }

    _sessionStatuses.remove(sessionId);
    _sessionTitles.remove(sessionId);
    _latestAssistantText.remove(sessionId);
    _pendingQuestions.remove(sessionId);
    _pendingPermissions.remove(sessionId);
    _previouslyBusy.remove(sessionId);
    _permissionRequestToSession.removeWhere((_, value) => value == sessionId);
  }

  void _handleMessagePartUpdated(MessagePart part) {
    if (part.type != "text") {
      return;
    }

    if (_messageRoles[part.messageID] != "assistant") {
      return;
    }

    _latestAssistantText[part.sessionID] = part.text ?? "";
  }
}
