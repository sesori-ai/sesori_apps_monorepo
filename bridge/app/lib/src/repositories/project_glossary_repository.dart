import "dart:convert";
import "dart:io" show FileSystemEntityType;

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryWordsRequest;

import "../api/filesystem_api.dart";
import "../api/git_cli_api.dart";
import "../api/git_tracked_files_api.dart";
import "../api/sesori_server_api.dart";
import "../foundation/abortable_request.dart";
import "mappers/git_remote_identity_parser.dart";
import "models/project_glossary_source.dart";

/// Loads bounded local glossary evidence and persists selected words through
/// the authenticated Sesori server API.
class ProjectGlossaryRepository({
  required final GitCliApi _gitCliApi,
  required final GitTrackedFilesApi _gitTrackedFilesApi,
  required final FilesystemApi _filesystemApi,
  required final SesoriServerApi _serverApi,
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

  Future<List<String>> getWords({
    required String projectKey,
    required AbortSignal abortSignal,
  }) async {
    final response = await _serverApi.getProjectGlossary(
      projectKey: projectKey,
      abortSignal: abortSignal,
    );
    return response.words;
  }

  Future<List<String>> addWords({
    required String projectKey,
    required List<String> words,
    required AbortSignal abortSignal,
  }) async {
    final response = await _serverApi.addProjectGlossaryWords(
      request: ProjectGlossaryWordsRequest(projectKey: projectKey, words: words),
      abortSignal: abortSignal,
    );
    return response.added;
  }

  Future<ProjectGlossarySource> loadSource({required String projectPath}) async {
    final rootEntryNames = _filesystemApi.listEntryNames(projectPath);
    final isGitProject = await _gitCliApi.isInsideGitWorkTree(projectPath: projectPath);
    final repositoryName = isGitProject ? await _readRepositoryName(projectPath: projectPath) : null;
    final sourcePaths = isGitProject
        ? await _gitTrackedFilesApi.listTrackedFiles(projectPath: projectPath, maximumPaths: _maximumTrackedPaths)
        : rootEntryNames.take(_maximumTrackedPaths);
    final trackedPaths = sourcePaths.where((path) => !_isExcludedPath(path)).toList(growable: false);
    final metadataPaths = <String>{
      for (final path in trackedPaths)
        if (_isMetadataPath(path)) path,
      if (!isGitProject)
        for (final entryName in rootEntryNames)
          if (_isMetadataPath(entryName)) entryName,
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
    try {
      final remoteUrl = await _gitCliApi.getRemoteUrl(projectPath: projectPath);
      if (remoteUrl == null) return null;
      final identity = _remoteIdentityParser.parse(remoteUrl: remoteUrl);
      return identity == null ? null : p.basename(identity.slug);
    } on Object catch (error, stackTrace) {
      Log.w("Could not read the project remote while inferring glossary terms", error, stackTrace);
      return null;
    }
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
