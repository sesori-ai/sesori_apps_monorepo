import "dart:convert";
import "dart:io" show FileSystemEntityType;

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../api/filesystem_api.dart";
import "../api/git_cli_api.dart";
import "mappers/git_remote_identity_parser.dart";
import "models/project_glossary_source.dart";

/// Loads bounded bridge-local evidence for deterministic glossary inference.
class ProjectGlossaryRepository({
  required final GitCliApi _gitCliApi,
  required final FilesystemApi _filesystemApi,
}) {
  static const GitRemoteIdentityParser _remoteIdentityParser = GitRemoteIdentityParser();
  static const int _maximumTrackedPaths = 50000;
  static const int _maximumMetadataFiles = 24;
  static const int _maximumMetadataBytes = 32 * 1024;

  static const Set<String> _excludedPathSegments = {
    ".dart_tool",
    ".git",
    ".gradle",
    ".idea",
    ".next",
    ".pub-cache",
    ".venv",
    ".vscode",
    "build",
    "coverage",
    "dist",
    "generated",
    "node_modules",
    "out",
    "target",
    "vendor",
  };

  static const Set<String> _metadataFileNames = {
    "build.gradle",
    "build.gradle.kts",
    "cargo.toml",
    "composer.json",
    "gemfile",
    "go.mod",
    "mix.exs",
    "package.json",
    "package.swift",
    "pom.xml",
    "pubspec.yaml",
    "pyproject.toml",
    "settings.gradle",
    "settings.gradle.kts",
  };

  Future<ProjectGlossarySource> loadSource({required String projectPath}) async {
    final isGitProject = await _gitCliApi.isInsideGitWorkTree(projectPath: projectPath);
    final repositoryName = isGitProject ? await _readRepositoryName(projectPath: projectPath) : null;
    final sourcePaths = isGitProject
        ? await _gitCliApi.listTrackedFiles(
            projectPath: projectPath,
            maximumPaths: _maximumTrackedPaths,
          )
        : await _filesystemApi.listEntryNamesBounded(
            path: projectPath,
            maximumEntries: _maximumTrackedPaths,
          );
    final trackedPaths = sourcePaths.where((path) => !_isExcludedPath(path)).toList(growable: false)..sort();
    final metadataPaths = <String>{
      for (final path in trackedPaths)
        if (_isMetadataPath(path)) path,
    }.toList()..sort(_compareMetadataPaths);

    return ProjectGlossarySource(
      projectName: p.basename(p.normalize(projectPath)),
      repositoryName: repositoryName,
      trackedPaths: trackedPaths,
      metadataDocuments: await _readMetadataDocuments(
        projectPath: projectPath,
        relativePaths: metadataPaths.take(_maximumMetadataFiles),
      ),
    );
  }

  Future<String?> _readRepositoryName({required String projectPath}) async {
    final remoteUrl = await _gitCliApi.getRemoteUrl(projectPath: projectPath);
    if (remoteUrl == null) return null;
    final identity = _remoteIdentityParser.parse(remoteUrl: remoteUrl);
    return identity == null ? null : p.basename(identity.slug);
  }

  bool _isExcludedPath(String relativePath) {
    final segments = p.split(relativePath).map((segment) => segment.toLowerCase());
    if (segments.any(_excludedPathSegments.contains)) return true;

    final lower = relativePath.toLowerCase();
    return lower.endsWith(".freezed.dart") ||
        lower.endsWith(".g.dart") ||
        lower.endsWith(".min.js") ||
        lower.endsWith(".min.css");
  }

  bool _isMetadataPath(String relativePath) {
    final basename = p.basename(relativePath).toLowerCase();
    return basename == "readme" || basename.startsWith("readme.") || _metadataFileNames.contains(basename);
  }

  int _compareMetadataPaths(String left, String right) {
    final leftDepth = p.split(left).length;
    final rightDepth = p.split(right).length;
    final depthOrder = leftDepth.compareTo(rightDepth);
    if (depthOrder != 0) return depthOrder;

    final leftReadme = p.basename(left).toLowerCase().startsWith("readme") ? 0 : 1;
    final rightReadme = p.basename(right).toLowerCase().startsWith("readme") ? 0 : 1;
    final kindOrder = leftReadme.compareTo(rightReadme);
    if (kindOrder != 0) return kindOrder;
    return left.compareTo(right);
  }

  Future<List<String>> _readMetadataDocuments({
    required String projectPath,
    required Iterable<String> relativePaths,
  }) async {
    final documents = <String>[];
    for (final relativePath in relativePaths) {
      final absolutePath = p.normalize(p.join(projectPath, relativePath));
      if (!p.isWithin(projectPath, absolutePath)) continue;

      try {
        if (_filesystemApi.entityType(absolutePath) != FileSystemEntityType.file) continue;
        final bytes = _filesystemApi.readFilePrefix(path: absolutePath, maxBytes: _maximumMetadataBytes);
        if (bytes.isEmpty) continue;
        documents.add(
          utf8.decode(bytes.take(_maximumMetadataBytes).toList(growable: false), allowMalformed: true),
        );
      } on Object catch (error, stackTrace) {
        Log.w("Could not read project glossary metadata at $absolutePath", error, stackTrace);
      }
    }
    return documents;
  }
}
