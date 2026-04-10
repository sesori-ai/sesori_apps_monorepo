import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/project_api.dart";

@lazySingleton
class ProjectRepository {
  final ProjectApi _projectApi;

  ProjectRepository(ProjectApi projectApi) : _projectApi = projectApi;

  Future<ApiResponse<BranchListResponse>> listBranches({required String projectId}) {
    return _projectApi.listBranches(projectId: projectId);
  }
}
