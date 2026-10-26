import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";

/// Layer-1 transport access for the client's current session declaration.
@lazySingleton
class ViewDeclarationApi({required final ConnectionService _connectionService}) {
  Future<void> sendSessionView({required String? sessionId}) {
    return _connectionService.sendSessionView(sessionId: sessionId);
  }
}
