import "package:injectable/injectable.dart";

import "../api/view_declaration_api.dart";

/// Layer-2 access to the client's current session and project declarations.
@lazySingleton
class ViewDeclarationRepository({required final ViewDeclarationApi _api}) {
  Future<void> sendSessionView({required String? sessionId}) {
    return _api.sendSessionView(sessionId: sessionId);
  }

  Future<void> sendProjectView({required String? projectId}) {
    return _api.sendProjectView(projectId: projectId);
  }
}
