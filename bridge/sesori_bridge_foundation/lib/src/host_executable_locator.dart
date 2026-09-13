import "dart:io";

import "package:path/path.dart" as p;

/// Whether the executable path a host process would resolve is present.
enum HostExecutablePresence() {
  present,
  absent,
  unknown,
}

/// Read-only host lookup used to distinguish an absent command from a present
/// but unlaunchable shim or broken symbolic link.
///
/// This concrete class is injectable directly; Dart test fakes may implement it
/// without requiring a one-to-one interface.
class const IoHostExecutableLocator({required final bool? platformIsWindows}) {
  bool get isWindows => platformIsWindows ?? Platform.isWindows;
  p.Context get _paths => p.Context(style: isWindows ? p.Style.windows : p.Style.posix);

  /// Whether [error] is the host's unambiguous command-not-found result.
  ///
  /// POSIX error code 3 has unrelated meanings, while Windows uses it for a
  /// missing path.
  bool isProcessMissingError({required ProcessException error}) =>
      error.errorCode == 2 || (isWindows && error.errorCode == 3);

  /// Whether host lookup positively proves [executable] is absent.
  ///
  /// Unknown lookup results remain authoritative and therefore return false.
  bool isPathCommandAbsent({
    required String executable,
    required Map<String, String>? environment,
    required String? workingDirectory,
  }) =>
      locate(executable: executable, environment: environment, workingDirectory: workingDirectory) ==
      HostExecutablePresence.absent;

  HostExecutablePresence locate({
    required String executable,
    required Map<String, String>? environment,
    required String? workingDirectory,
  }) {
    if (executable.isEmpty) return HostExecutablePresence.unknown;

    final extensions = isWindows && _paths.extension(executable).isEmpty
        ? (_environmentValue(environment: environment, name: "PATHEXT") ??
                  _environmentValue(environment: Platform.environment, name: "PATHEXT") ??
                  ".COM;.EXE;.BAT;.CMD")
              .split(";")
              .where((extension) => extension.isNotEmpty)
              .toList(growable: false)
        : const [""];
    if (executable.contains("/") || (isWindows && executable.contains(r"\"))) {
      final resolvedExecutable = _paths.isAbsolute(executable)
          ? executable
          : _paths.join(workingDirectory ?? Directory.current.path, executable);
      final candidates = <String>[];
      _addCandidates(
        candidates: candidates,
        directory: _paths.dirname(resolvedExecutable),
        executable: _paths.basename(resolvedExecutable),
        extensions: isWindows && _paths.extension(resolvedExecutable).isEmpty ? ["", ...extensions] : extensions,
      );
      return _inspectCandidates(candidates: candidates);
    }

    final candidates = <String>[];
    if (isWindows) {
      _addCandidates(
        candidates: candidates,
        directory: workingDirectory ?? Directory.current.path,
        executable: executable,
        extensions: extensions,
      );
    }

    final pathValue =
        _environmentValue(environment: environment, name: "PATH") ??
        _environmentValue(environment: Platform.environment, name: "PATH");
    if (pathValue == null) {
      final currentDirectoryPresence = _inspectCandidates(candidates: candidates);
      return currentDirectoryPresence == HostExecutablePresence.present
          ? HostExecutablePresence.present
          : HostExecutablePresence.unknown;
    }

    final baseDirectory = workingDirectory ?? Directory.current.path;
    for (final rawDirectory in pathValue.split(isWindows ? ";" : ":")) {
      final directory = isWindows ? _unquote(value: rawDirectory.trim()) : rawDirectory;
      final resolvedDirectory = directory.isEmpty
          ? baseDirectory
          : _paths.isAbsolute(directory)
          ? directory
          : _paths.join(baseDirectory, directory);
      _addCandidates(
        candidates: candidates,
        directory: resolvedDirectory,
        executable: executable,
        extensions: extensions,
      );
    }
    return _inspectCandidates(candidates: candidates);
  }

  void _addCandidates({
    required List<String> candidates,
    required String directory,
    required String executable,
    required List<String> extensions,
  }) {
    for (final extension in extensions) {
      candidates.add(_paths.join(directory, "$executable$extension"));
    }
  }

  HostExecutablePresence _inspectCandidates({required List<String> candidates}) {
    var hadUnknown = false;
    for (final candidate in candidates) {
      final presence = _inspectCandidate(candidate: candidate);
      if (presence == HostExecutablePresence.present) return presence;
      if (presence == HostExecutablePresence.unknown) hadUnknown = true;
    }
    return hadUnknown ? HostExecutablePresence.unknown : HostExecutablePresence.absent;
  }

  HostExecutablePresence _inspectCandidate({required String candidate}) {
    if (candidate.contains("\u0000")) return HostExecutablePresence.unknown;
    try {
      if (FileSystemEntity.typeSync(candidate, followLinks: false) != FileSystemEntityType.notFound) {
        return HostExecutablePresence.present;
      }
    } on FileSystemException {
      return HostExecutablePresence.unknown;
    }

    // dart:io reports notFound for both a missing entry and some inaccessible
    // paths. A read-only open preserves the specific failure: only a true
    // PathNotFoundException proves absence, while permission and filesystem
    // failures remain unknown and therefore authoritative.
    try {
      File(candidate).openSync().closeSync();
      return HostExecutablePresence.present;
    } on PathNotFoundException {
      return HostExecutablePresence.absent;
    } on FileSystemException {
      return HostExecutablePresence.unknown;
    }
  }

  String? _environmentValue({
    required Map<String, String>? environment,
    required String name,
  }) {
    if (environment == null) return null;
    if (!isWindows) return environment[name];
    final normalizedName = name.toLowerCase();
    for (final entry in environment.entries) {
      if (entry.key.toLowerCase() == normalizedName) return entry.value;
    }
    return null;
  }

  String _unquote({required String value}) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}
