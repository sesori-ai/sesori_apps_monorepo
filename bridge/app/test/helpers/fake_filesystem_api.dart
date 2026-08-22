import "dart:io" show FileSystemException;

import "package:sesori_bridge/src/api/filesystem_api.dart";

/// Test fake for [FilesystemApi]. By default every path reports as an existing
/// directory, so a repository built with it keeps `Project.directoryMissing`
/// false — matching behaviour from before the existence check existed.
///
/// Pass [missingPaths] for directories that should report as absent (to
/// exercise the "folder moved/deleted" flag) and [throwingPaths] for
/// directories whose existence probe raises a [FileSystemException] (a
/// permission or other IO error), which the repository treats as present.
class FakeFilesystemApi({
  final Set<String> _missingPaths = const {},
  final Set<String> _throwingPaths = const {},
}) implements FilesystemApi {
  @override
  bool directoryExists(String path) {
    if (_throwingPaths.contains(path)) {
      throw const FileSystemException("permission denied");
    }
    return !_missingPaths.contains(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
