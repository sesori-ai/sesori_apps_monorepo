import "dart:io";

import "package:path/path.dart" as p;

/// Whether the executable path a host process would resolve is present.
enum HostExecutablePresence() {
  present,
  absent,
  unknown,
}

/// Read-only PATH lookup used to distinguish an absent command from a present
/// but unlaunchable shim or broken symbolic link.
abstract interface class HostExecutableLocator() {
  bool get isWindows;

  HostExecutablePresence locate({
    required String executable,
    required Map<String, String>? environment,
    required String? workingDirectory,
  });
}

class const IoHostExecutableLocator({required final bool? platformIsWindows}) implements HostExecutableLocator {
  @override
  bool get isWindows => platformIsWindows ?? Platform.isWindows;

  @override
  HostExecutablePresence locate({
    required String executable,
    required Map<String, String>? environment,
    required String? workingDirectory,
  }) {
    if (executable.contains("/") || executable.contains(r"\")) {
      final resolvedExecutable = workingDirectory != null && !p.isAbsolute(executable)
          ? p.join(workingDirectory, executable)
          : executable;
      return _inspectCandidates([resolvedExecutable]);
    }

    final extensions = isWindows && p.extension(executable).isEmpty
        ? (_environmentValue(environment: environment, name: "PATHEXT") ??
                  _environmentValue(environment: Platform.environment, name: "PATHEXT") ??
                  ".COM;.EXE;.BAT;.CMD")
              .split(";")
              .where((extension) => extension.isNotEmpty)
              .toList(growable: false)
        : const [""];
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
      final currentDirectoryPresence = _inspectCandidates(candidates);
      return currentDirectoryPresence == HostExecutablePresence.present
          ? HostExecutablePresence.present
          : HostExecutablePresence.unknown;
    }

    for (final rawDirectory in pathValue.split(isWindows ? ";" : ":")) {
      final directory = _unquote(rawDirectory.trim());
      _addCandidates(
        candidates: candidates,
        directory: directory.isEmpty ? workingDirectory ?? Directory.current.path : directory,
        executable: executable,
        extensions: extensions,
      );
    }
    return _inspectCandidates(candidates);
  }

  void _addCandidates({
    required List<String> candidates,
    required String directory,
    required String executable,
    required List<String> extensions,
  }) {
    for (final extension in extensions) {
      candidates.add(p.join(directory, "$executable$extension"));
    }
  }

  HostExecutablePresence _inspectCandidates(List<String> candidates) {
    var hadUnknown = false;
    for (final candidate in candidates) {
      if (candidate.contains("\u0000")) {
        hadUnknown = true;
        continue;
      }
      try {
        if (FileSystemEntity.typeSync(candidate, followLinks: false) != FileSystemEntityType.notFound) {
          return HostExecutablePresence.present;
        }
      } on FileSystemException {
        hadUnknown = true;
      }
    }
    return hadUnknown ? HostExecutablePresence.unknown : HostExecutablePresence.absent;
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

  String _unquote(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}
