import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "request_handler.dart";

/// Handles `POST /filesystem/directory` — creates one plain directory inside an
/// existing parent, for the client's directory browser.
///
/// Deliberately narrower than `POST /project/create`: it only makes the folder,
/// leaving git setup and project registration to a following `/project/open`.
/// That keeps "create a place to work in" separate from "start tracking it", so
/// the browser can drop the user into the new folder first.
///
/// The created directory is returned as a [FilesystemSuggestion] — the same
/// entry shape the browser's listing is made of — so the client navigates to
/// the path this host actually produced instead of re-deriving it.
class CreateDirectoryHandler extends BodyRequestHandler<FilesystemCreateDirectoryRequest, FilesystemSuggestion> {
  final FilesystemRepository _filesystemRepository;

  CreateDirectoryHandler({required FilesystemRepository filesystemRepository})
    : _filesystemRepository = filesystemRepository,
      super(
        HttpMethod.post,
        "/filesystem/directory",
        fromJson: FilesystemCreateDirectoryRequest.fromJson,
      );

  @override
  Future<FilesystemSuggestion> handle(
    RelayRequest request, {
    required FilesystemCreateDirectoryRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final parentPath = body.parentPath;
    final name = body.name.trim();

    if (parentPath.isEmpty) {
      throw buildErrorResponse(request, 400, "parentPath must not be empty");
    }
    if (!p.isAbsolute(parentPath)) {
      throw buildErrorResponse(request, 400, "parentPath must be absolute");
    }
    if (name.isEmpty) {
      throw buildErrorResponse(request, 400, "name must not be empty");
    }
    // The name is one path segment, never a route: anything that separates,
    // reroots, or walks up would place the directory outside [parentPath].
    if (name.contains("/") || name.contains(r"\") || name == "." || name == "..") {
      throw buildErrorResponse(request, 400, "name must be a single path segment");
    }
    if (p.split(parentPath).contains("..")) {
      throw buildErrorResponse(request, 400, "path traversal not allowed");
    }

    final path = p.join(parentPath, name);

    try {
      switch (_filesystemRepository.checkCreatableDirectory(path: path)) {
        case CreatableDirectoryStatus.parentMissing:
          throw buildErrorResponse(request, 400, "parent directory does not exist");
        case CreatableDirectoryStatus.alreadyExists:
          throw buildErrorResponse(request, 409, "directory already exists");
        case CreatableDirectoryStatus.creatable:
          _filesystemRepository.createDirectory(path: path);
      }
    } on FilesystemPermissionDeniedException {
      throw buildErrorResponse(request, 403, "permission denied: $path");
    } on FileSystemException catch (error, stackTrace) {
      Log.w("CreateDirectoryHandler: failed to create $path", error, stackTrace);
      throw buildErrorResponse(request, 500, "failed to create directory");
    }

    // Freshly created, so it holds no repository yet.
    return FilesystemSuggestion(path: path, name: name, isGitRepo: false);
  }
}
