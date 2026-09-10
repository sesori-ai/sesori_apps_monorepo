import "dart:io" as io;

import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/open_code_catalog_database_api.dart";
import "../plugin_model_mapper.dart";

const String _globalProjectId = "global";
const int _mappingBatchSize = 512;

typedef OpenCodeCatalogFileExists = bool Function({required String path});

enum _OpenCodeProjectDirectoryType() {
  main,
  root,
  gitWorktree;

  static _OpenCodeProjectDirectoryType parse({required String value}) => switch (value) {
    "main" => main,
    "root" => root,
    "git_worktree" => gitWorktree,
    _ => throw const OpenCodeCatalogDatabaseException(
      message: "Unknown OpenCode project_directory.type",
      cause: null,
    ),
  };
}

/// Layer-2 OpenCode catalog assembly over its read-only database API.
class OpenCodeCatalogRepository({
  required final OpenCodeCatalogDatabaseApi databaseApi,
  required final PluginModelMapper modelMapper,
  required final PlatformOs operatingSystem,
  required final OpenCodeCatalogFileExists fileExists,
  required final String? trustedInstallationChannel,
}) {
  Future<PluginCatalogSnapshotResult> read({
    required Map<String, String> environment,
    required PluginCatalogCancellationSignal cancellation,
  }) async {
    final databasePath = _resolveDatabasePath(environment: environment);
    if (databasePath == null || !fileExists(path: databasePath)) {
      return const PluginCatalogSnapshotUnavailable();
    }
    if (cancellation.isCancelled) throw const PluginStartAbortedException();
    final raw = await databaseApi.read(databasePath: databasePath);
    if (cancellation.isCancelled) throw const PluginStartAbortedException();
    final snapshot = await _mapSnapshot(raw: raw, cancellation: cancellation);
    return PluginCatalogSnapshotAvailable(snapshot: snapshot);
  }

  String? _resolveDatabasePath({required Map<String, String> environment}) {
    final context = path.Context(
      style: operatingSystem == PlatformOs.windows ? path.Style.windows : path.Style.posix,
    );
    final override = environment["OPENCODE_DB"];
    if (override != null && override.isNotEmpty) {
      if (override == ":memory:") return null;
      if (context.isAbsolute(override)) return override;
      final dataRoot = _resolveDataRoot(environment: environment, context: context);
      return dataRoot == null ? null : context.join(dataRoot, override);
    }
    final dataRoot = _resolveDataRoot(environment: environment, context: context);
    if (dataRoot == null) return null;
    final disablesChannelDatabase = switch (environment["OPENCODE_DISABLE_CHANNEL_DB"]) {
      "1" || "true" => true,
      _ => false,
    };
    const publicChannels = {"latest", "beta", "prod"};
    if (!disablesChannelDatabase && !publicChannels.contains(trustedInstallationChannel)) return null;
    return context.join(dataRoot, "opencode.db");
  }

  String? _resolveDataRoot({
    required Map<String, String> environment,
    required path.Context context,
  }) {
    final xdg = environment["XDG_DATA_HOME"];
    if (xdg case final value? when value.isNotEmpty) {
      if (!context.isAbsolute(value)) return null;
      return context.join(value, "opencode");
    }
    final home = resolveUserHomeDirectory(environment: environment);
    if (home == null || home.isEmpty || !context.isAbsolute(home)) return null;
    return context.join(home, ".local", "share", "opencode");
  }

  Future<PluginCatalogSnapshot> _mapSnapshot({
    required OpenCodeCatalogDatabaseSnapshot raw,
    required PluginCatalogCancellationSignal cancellation,
  }) async {
    final projectsById = <String, OpenCodeCatalogProjectRow>{};
    for (final project in raw.projects) {
      if (projectsById.containsKey(project.id)) {
        throw const OpenCodeCatalogDatabaseException(message: "Duplicate OpenCode project id", cause: null);
      }
      projectsById[project.id] = OpenCodeCatalogProjectRow(
        id: project.id,
        worktree: _canonicalAbsolutePath(value: project.worktree, field: "project.worktree"),
        name: project.name,
        createdAt: project.createdAt,
        updatedAt: project.updatedAt,
        sandboxes: [
          for (final sandbox in project.sandboxes) _canonicalAbsolutePath(value: sandbox, field: "project.sandboxes[]"),
        ],
      );
    }
    final aliasesByProjectId = <String, Set<String>>{
      for (final project in projectsById.values)
        if (project.id != _globalProjectId) project.id: {project.worktree, ...project.sandboxes},
    };
    for (final directory in raw.projectDirectories) {
      if (!projectsById.containsKey(directory.projectId)) {
        throw const OpenCodeCatalogDatabaseException(
          message: "OpenCode project_directory references an unknown project",
          cause: null,
        );
      }
      final type = directory.type;
      if (type != null) _OpenCodeProjectDirectoryType.parse(value: type);
      final canonicalDirectory = _canonicalAbsolutePath(
        value: directory.directory,
        field: "project_directory.directory",
      );
      if (directory.projectId != _globalProjectId) {
        aliasesByProjectId[directory.projectId]!.add(canonicalDirectory);
      }
    }

    final sessionsById = <String, OpenCodeCatalogSessionRow>{};
    final childrenByParent = <String, List<OpenCodeCatalogSessionRow>>{};
    for (var index = 0; index < raw.sessions.length; index++) {
      final session = raw.sessions[index];
      if (!projectsById.containsKey(session.projectId)) {
        throw const OpenCodeCatalogDatabaseException(
          message: "OpenCode session references an unknown project",
          cause: null,
        );
      }
      if (sessionsById.containsKey(session.id)) {
        throw const OpenCodeCatalogDatabaseException(message: "Duplicate OpenCode session id", cause: null);
      }
      final canonicalSession = OpenCodeCatalogSessionRow(
        id: session.id,
        projectId: session.projectId,
        parentId: session.parentId,
        directory: _canonicalAbsolutePath(value: session.directory, field: "session.directory"),
        title: session.title,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
        archivedAt: session.archivedAt,
      );
      sessionsById[session.id] = canonicalSession;
      final parentId = canonicalSession.parentId;
      if (parentId != null) childrenByParent.putIfAbsent(parentId, () => []).add(canonicalSession);
      if (index % _mappingBatchSize == 0) {
        if (cancellation.isCancelled) throw const PluginStartAbortedException();
        await Future<void>.delayed(Duration.zero);
      }
    }
    _validateAncestry(sessionsById: sessionsById);

    final families = <String, _CatalogFamily>{};
    for (final project in projectsById.values) {
      if (project.id == _globalProjectId) continue;
      families[project.id] = _CatalogFamily(project: project, roots: [], sessions: []);
    }

    for (final root in sessionsById.values.where((session) => session.parentId == null)) {
      final familyId = _bestFamilyFor(directory: root.directory, aliasesByProjectId: aliasesByProjectId);
      if (familyId == null) {
        if (root.projectId != _globalProjectId) {
          throw const OpenCodeCatalogDatabaseException(
            message: "OpenCode root session is outside its project directories",
            cause: null,
          );
        }
        final virtualId = "virtual:${_normalizedPath(root.directory)}";
        families.putIfAbsent(
          virtualId,
          () => _CatalogFamily(
            project: OpenCodeCatalogProjectRow(
              id: virtualId,
              worktree: root.directory,
              name: null,
              createdAt: root.createdAt,
              updatedAt: root.updatedAt,
              sandboxes: const [],
            ),
            roots: [],
            sessions: [],
          ),
        );
        families[virtualId]!.roots.add(root);
      } else {
        families[familyId]!.roots.add(root);
      }
    }

    for (final family in families.values) {
      final pending = [...family.roots];
      final included = <String>{};
      while (pending.isNotEmpty) {
        final session = pending.removeLast();
        if (!included.add(session.id)) continue;
        family.sessions.add(session);
        pending.addAll(childrenByParent[session.id] ?? const []);
      }
    }

    final result = <PluginProjectCatalogSnapshot>[];
    var mapped = 0;
    for (final family in families.values) {
      final worktree = family.project.worktree;
      final activity = _activity(roots: family.roots);
      final project = modelMapper.mapProject(
        worktree: worktree,
        directory: worktree,
        name: family.project.name,
        activity: activity,
      );
      final sessions = <PluginSession>[];
      for (final rawSession in family.sessions) {
        sessions.add(
          modelMapper.mapCatalogSession(
            id: rawSession.id,
            projectID: worktree,
            directory: rawSession.directory,
            parentID: rawSession.parentId,
            title: rawSession.title,
            createdAt: rawSession.createdAt,
            updatedAt: rawSession.updatedAt,
            archivedAt: rawSession.archivedAt,
          ),
        );
        mapped++;
        if (mapped % _mappingBatchSize == 0) {
          if (cancellation.isCancelled) throw const PluginStartAbortedException();
          await Future<void>.delayed(Duration.zero);
        }
      }
      result.add(PluginProjectCatalogSnapshot(project: project, sessions: List.unmodifiable(sessions)));
    }
    if (cancellation.isCancelled) throw const PluginStartAbortedException();
    return PluginCatalogSnapshot(projects: List.unmodifiable(result));
  }

  void _validateAncestry({required Map<String, OpenCodeCatalogSessionRow> sessionsById}) {
    final complete = <String>{};
    for (final id in sessionsById.keys) {
      final visiting = <String>{};
      var current = id;
      while (!complete.contains(current)) {
        if (!visiting.add(current)) {
          throw const OpenCodeCatalogDatabaseException(message: "Cyclic OpenCode session ancestry", cause: null);
        }
        final parent = sessionsById[current]?.parentId;
        if (parent == null) break;
        if (!sessionsById.containsKey(parent)) {
          throw const OpenCodeCatalogDatabaseException(message: "Missing OpenCode session parent", cause: null);
        }
        current = parent;
      }
      complete.addAll(visiting);
    }
  }

  String? _bestFamilyFor({required String directory, required Map<String, Set<String>> aliasesByProjectId}) {
    String? result;
    var longest = -1;
    for (final entry in aliasesByProjectId.entries) {
      for (final alias in entry.value) {
        if (_isUnder(directory: directory, root: alias) && alias.length > longest) {
          result = entry.key;
          longest = alias.length;
        }
      }
    }
    return result;
  }

  PluginProjectActivity? _activity({required List<OpenCodeCatalogSessionRow> roots}) {
    if (roots.isEmpty) return null;
    return PluginProjectActivity(
      createdAt: roots.map((session) => session.createdAt).reduce((left, right) => left < right ? left : right),
      updatedAt: roots.map((session) => session.updatedAt).reduce((left, right) => left > right ? left : right),
    );
  }

  String _canonicalAbsolutePath({required String value, required String field}) {
    final context = path.Context(
      style: operatingSystem == PlatformOs.windows ? path.Style.windows : path.Style.posix,
    );
    if (value.isEmpty || !context.isAbsolute(value)) {
      throw OpenCodeCatalogDatabaseException(message: "Invalid $field", cause: null);
    }
    return context.normalize(value);
  }

  bool _isUnder({required String directory, required String root}) {
    final normalizedDirectory = _comparisonPath(value: directory);
    final normalizedRoot = _comparisonPath(value: root);
    if (normalizedRoot == "/") return true;
    return normalizedDirectory == normalizedRoot || normalizedDirectory.startsWith("$normalizedRoot/");
  }

  String _comparisonPath({required String value}) {
    final normalized = _normalizedPath(value);
    return operatingSystem == PlatformOs.windows ? normalized.toLowerCase() : normalized;
  }

  String _normalizedPath(String value) {
    final normalized = value.replaceAll(r"\", "/");
    return normalized.length > 1 && normalized.endsWith("/")
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }
}

class _CatalogFamily({
  required final OpenCodeCatalogProjectRow project,
  required final List<OpenCodeCatalogSessionRow> roots,
  required final List<OpenCodeCatalogSessionRow> sessions,
});

bool openCodeCatalogFileExists({required String path}) => io.File(path).existsSync();
