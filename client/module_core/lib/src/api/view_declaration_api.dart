import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";

/// Layer-1 transport access for the client's current session and project
/// declarations.
@lazySingleton
class ViewDeclarationApi({required final ConnectionService _connectionService}) {
  Future<void> sendSessionView({required String? sessionId}) {
    return _connectionService.sendSessionView(sessionId: sessionId);
  }

  Future<void> sendProjectView({required String? projectId}) {
    return _connectionService.sendProjectView(projectId: projectId);
  }
}
