import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "request_handler.dart";

/// Handles `POST /filesystem/file` — returns a read-only preview of any
/// readable file on the host by absolute path. Every domain outcome, such as
/// a missing or too large file, is answered with 200.
class ReadFilePreviewHandler({required final FilesystemRepository _filesystemRepository})
    extends BodyRequestHandler<FilePreviewRequest, FilePreviewResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/filesystem/file",
        fromJson: FilePreviewRequest.fromJson,
      );

  @override
  Future<FilePreviewResponse> handle({
    required RelayRequest request,
    required FilePreviewRequest body,
  }) async {
    final path = body.path;
    if (!p.isAbsolute(path)) {
      throw buildErrorResponse(request: request, status: 400, message: "path must be absolute");
    }
    if (p.split(path).contains("..")) {
      throw buildErrorResponse(request: request, status: 400, message: "path traversal not allowed");
    }

    try {
      return _filesystemRepository.readPreviewFile(absolutePath: path);
    } on FileSystemException catch (error, stackTrace) {
      Log.w("ReadFilePreviewHandler: failed to read $path", error, stackTrace);
      throw buildErrorResponse(request: request, status: 500, message: "failed to read file");
    }
  }
}
