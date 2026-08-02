import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";

/// Layer-1 transport access for project-presence declarations.
@lazySingleton
class ProjectViewApi {
  final ConnectionService _connectionService;

  ProjectViewApi({required ConnectionService connectionService}) : _connectionService = connectionService;

  Future<void> sendProjectView({required String? projectId}) {
    return _connectionService.sendProjectView(projectId: projectId);
  }
}
