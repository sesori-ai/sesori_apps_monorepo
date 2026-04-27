import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mappers/plugin_project_mapper.dart";
import "request_handler.dart";

/// Handles `POST /project/create` — creates a new project directory with git init.
class CreateProjectHandler extends BodyRequestHandler<ProjectPathRequest, Project> {
  final BridgePluginApi _plugin;

  CreateProjectHandler(this._plugin)
    : super(
        HttpMethod.post,
        "/project/create",
        fromJson: ProjectPathRequest.fromJson,
      );

  @override
  Future<Project> handle(
    RelayRequest request, {
    required ProjectPathRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final path = body.path;

    if (path.isEmpty) {
      throw buildErrorResponse(request, 400, "path must not be empty");
    }
    if (!path.startsWith("/")) {
      throw buildErrorResponse(request, 400, "path must be absolute");
    }
    if (path.contains("..")) {
      throw buildErrorResponse(request, 400, "path traversal not allowed");
    }

    final parentDir = Directory(path).parent;
    if (!parentDir.existsSync()) {
      throw buildErrorResponse(request, 400, "parent directory does not exist");
    }

    if (Directory(path).existsSync()) {
      throw buildErrorResponse(request, 409, "directory already exists");
    }

    try {
      Directory(path).createSync(recursive: false);
    } on FileSystemException catch (error) {
      throw buildErrorResponse(request, 500, "failed to create directory: $error");
    }

    final gitResult = await Process.run("git", ["init", path]);
    if (gitResult.exitCode != 0) {
      throw buildErrorResponse(request, 500, "git init failed: ${gitResult.stderr}");
    }

    // Write .gitignore with .worktrees/ entry (idempotent)
    final gitignoreFile = File("$path/.gitignore");
    try {
      final content = gitignoreFile.existsSync() ? await gitignoreFile.readAsString() : "";
      if (!content.contains(".worktrees/")) {
        await gitignoreFile.writeAsString(".worktrees/\n", mode: FileMode.append);
      }
    } on FileSystemException catch (error) {
      throw buildErrorResponse(request, 500, "failed to write .gitignore: $error");
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

    return project;
  }
}
