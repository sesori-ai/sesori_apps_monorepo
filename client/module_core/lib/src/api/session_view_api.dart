import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";

/// Layer-1 transport access for the "currently viewing session" control
/// message. Its sole responsibility is sending the declaration through the
/// relay (via [ConnectionService]'s raw send primitive).
@lazySingleton
class SessionViewApi({required final ConnectionService _connectionService}) {
  /// Sends "I am now viewing [sessionId]" (or nothing when null).
  Future<void> sendSessionView({required String? sessionId}) {
    return _connectionService.sendSessionView(sessionId: sessionId);
  }
}
