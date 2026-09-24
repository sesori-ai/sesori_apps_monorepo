import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../services/project_list_service.dart";

/// The projects a new session page can switch to, for a shell that holds no
/// project inventory on that route. It stays empty until the list arrives or
/// when loading fails; the page then names the current project only.
class NewSessionProjectsCubit({required final ProjectListService _projectListService})
    extends Cubit<List<ProjectSummary>> {
  this : super(const []) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final response = await _projectListService.listProjects();
    if (isClosed) return;
    switch (response) {
      case SuccessResponse(:final data):
        emit(data.data);
      case ErrorResponse(:final error):
        logw("New session: failed to list projects for the project selector", error);
    }
  }
}
