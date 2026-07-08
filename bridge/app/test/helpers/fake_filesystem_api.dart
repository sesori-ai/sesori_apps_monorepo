import "dart:io" show FileSystemException;

import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";

/// Test fake for [FilesystemApi]. By default every path reports as an existing
/// directory, so a repository built with it keeps `Project.directoryMissing`
/// false — matching behaviour from before the existence check existed.
///
/// Pass [missingPaths] for directories that should report as absent (to
/// exercise the "folder moved/deleted" flag) and [throwingPaths] for
/// directories whose existence probe raises a [FileSystemException] (a
/// permission or other IO error), which the repository treats as present.
class FakeFilesystemApi implements FilesystemApi {
  FakeFilesystemApi({
    Set<String> missingPaths = const {},
    Set<String> throwingPaths = const {},
  }) : _missingPaths = missingPaths,
       _throwingPaths = throwingPaths;

  final Set<String> _missingPaths;
  final Set<String> _throwingPaths;

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
