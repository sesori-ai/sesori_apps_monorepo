import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "plugin_project_mapper.dart";
import "request_handler.dart";

/// Handles `POST /project/create` — creates a new project directory with git init.
class CreateProjectHandler extends RequestHandler {
  final BridgePlugin _plugin;

  CreateProjectHandler(this._plugin) : super(HttpMethod.post, "/project/create");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final CreateProjectRequest createRequest;
    try {
      final decoded = jsonDecode(request.body ?? "{}");
      createRequest = CreateProjectRequest.fromJson(
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

    final path = createRequest.path;
    if (path.isEmpty) {
      return buildErrorResponse(request, 400, "path must not be empty");
    }
    if (!path.startsWith("/")) {
      return buildErrorResponse(request, 400, "path must be absolute");
    }
    if (path.contains("..")) {
      return buildErrorResponse(request, 400, "path traversal not allowed");
    }

    final parentDir = Directory(path).parent;
    if (!parentDir.existsSync()) {
      return buildErrorResponse(request, 400, "parent directory does not exist");
    }

    if (Directory(path).existsSync()) {
      return buildErrorResponse(request, 409, "directory already exists");
    }

    try {
      Directory(path).createSync(recursive: false);
    } on FileSystemException catch (error) {
      return buildErrorResponse(request, 500, "failed to create directory: $error");
    }

    final gitResult = await Process.run("git", ["init", path]);
    if (gitResult.exitCode != 0) {
      return buildErrorResponse(request, 500, "git init failed: ${gitResult.stderr}");
    }

    // Write .gitignore with .worktrees/ entry (idempotent)
    final gitignoreFile = File("$path/.gitignore");
    try {
      final content = gitignoreFile.existsSync() ? await gitignoreFile.readAsString() : "";
      if (!content.contains(".worktrees/")) {
        await gitignoreFile.writeAsString(".worktrees/\n", mode: FileMode.append);
      }
    } on FileSystemException catch (error) {
      return buildErrorResponse(request, 500, "failed to write .gitignore: $error");
    }

    final addResult = await Process.run("git", ["add", "."], workingDirectory: path);
    if (addResult.exitCode != 0) {
      Log.w("CreateProjectHandler: git add failed for $path: ${addResult.stderr}");
    } else {
      final commitResult = await Process.run(
        "git",
        ["commit", "-m", "Initial commit"],
        workingDirectory: path,
      );
      if (commitResult.exitCode != 0) {
        Log.w("CreateProjectHandler: initial commit failed for $path: ${commitResult.stderr}");
      }
    }

    final pluginProject = await _plugin.getProject(path);
    final project = pluginProject.toSharedProject();

    return RelayResponse(
      id: request.id,
      status: 201,
      headers: {"content-type": "application/json"},
      body: jsonEncode(project.toJson()),
    );
  }
}
