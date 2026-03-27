import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "plugin_project_mapper.dart";
import "request_handler.dart";

/// Handles `PATCH /project/name` — renames a project.
class RenameProjectHandler extends RequestHandler {
  final BridgePlugin _plugin;

  RenameProjectHandler(this._plugin) : super(HttpMethod.patch, "/project/name");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final RenameProjectRequest renameRequest;
    try {
      final decoded = jsonDecode(request.body ?? "{}");
      renameRequest = RenameProjectRequest.fromJson(
        switch (decoded) {
          final Map<String, dynamic> map => map,
          _ => throw const FormatException("invalid JSON body"),
        },
      );
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    final updated = await _plugin.renameProject(
      projectId: renameRequest.projectId,
      name: renameRequest.name,
    );

    final project = updated.toSharedProject();

    return buildOkJsonResponse(request, jsonEncode(project.toJson()));
  }
}
