import "package:injectable/injectable.dart";

import "../api/session_view_api.dart";

/// Layer-2 access to the session-view control message. Thin pass-through to
/// [SessionViewApi] — present to satisfy the mandatory repository boundary
/// between services (Layer 3) and APIs (Layer 1).
@lazySingleton
class SessionViewRepository({required SessionViewApi api}) {
  final SessionViewApi _api;

  this : _api = api;

  Future<void> sendSessionView({required String? sessionId}) {
    return _api.sendSessionView(sessionId: sessionId);
  }
}
