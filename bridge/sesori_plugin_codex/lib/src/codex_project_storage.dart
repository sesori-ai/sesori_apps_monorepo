import "dart:convert";
import "dart:io";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeListMap;

part "codex_project_storage.freezed.dart";
part "codex_project_storage.g.dart";

/// One directory the user explicitly opened, created, or renamed from the app.
///
/// codex has no project concept of its own, so the plugin derives projects from
/// session CWDs. This record covers the gaps that derivation alone can't: a
/// directory with no codex sessions yet (so a freshly-added folder doesn't
/// vanish on the next refresh) and a custom display name (so a rename survives).
///
/// `path` is stored verbatim (NOT normalized) so it matches the rollout `cwd`
/// that the plugin uses as a project id elsewhere. `addedAt` (ms since epoch) is
/// used as the project's time when it has no sessions to derive one from. A
/// malformed entry that omits `path` decodes to an empty path and is skipped by
/// [CodexProjectStorage.listOpenedProjects].
@freezed
sealed class CodexOpenedProject with _$CodexOpenedProject {
  const factory CodexOpenedProject({
    @Default("") String path,
    String? name,
    @Default(0) int addedAt,
  }) = _CodexOpenedProject;

  factory CodexOpenedProject.fromJson(Map<String, dynamic> json) =>
      _$CodexOpenedProjectFromJson(json);
}

/// File-backed store of the project directories the user has explicitly opened,
/// created, or renamed from the app, persisted as a JSON array at
/// `<CODEX_HOME>/sesori_projects.json`.
///
/// CODEX_HOME resolution mirrors [SessionRolloutReader]/[CodexConfigReader]:
///   1. `$CODEX_HOME` if set.
///   2. `$HOME/.codex` (or `$USERPROFILE/.codex` on Windows).
///
/// All operations are best-effort: reads fail soft to an empty list; a write
/// failure is logged and dropped (the added folder simply won't survive a
/// restart) rather than thrown, since project listing must never break on a
/// single unwritable file.
class CodexProjectStorage {
  CodexProjectStorage({Map<String, String>? environment})
    : _environment = environment ?? Platform.environment;

  final Map<String, String> _environment;

  static const String _fileName = "sesori_projects.json";

  String? get codexHome {
    final explicit = _environment["CODEX_HOME"];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final home = _environment["HOME"] ?? _environment["USERPROFILE"];
    if (home == null || home.isEmpty) return null;
    return p.join(home, ".codex");
  }

  /// Absolute path to `sesori_projects.json`, or null when CODEX_HOME can't be
  /// resolved.
  String? get filePath {
    final home = codexHome;
    if (home == null) return null;
    return p.join(home, _fileName);
  }

  /// Every persisted opened/renamed project. Fails soft to `const []` on a
  /// missing file, an unresolvable home, or a parse/IO error; entries that
  /// decode without a usable path are skipped.
  List<CodexOpenedProject> listOpenedProjects() {
    final path = filePath;
    if (path == null) return const [];
    final file = File(path);
    if (!file.existsSync()) return const [];
    try {
      final entries = jsonDecodeListMap(file.readAsStringSync());
      return [
        for (final entry in entries)
          if (CodexOpenedProject.fromJson(entry) case final project
              when project.path.isNotEmpty)
            project,
      ];
    } catch (error, stackTrace) {
      Log.w("CodexProjectStorage: failed to read $path", error, stackTrace);
      return const [];
    }
  }

  /// Records [path] as an opened project. Idempotent: a new path is stamped with
  /// the current time; an existing path keeps its original `addedAt`. When
  /// [name] is non-null it sets/overrides the display name; a null [name] leaves
  /// any existing name intact.
  void upsertProject({required String path, String? name}) {
    final target = filePath;
    if (target == null) return;
    final byPath = <String, CodexOpenedProject>{
      for (final e in listOpenedProjects()) e.path: e,
    };
    final prior = byPath[path];
    byPath[path] = CodexOpenedProject(
      path: path,
      name: name ?? prior?.name,
      addedAt: prior?.addedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    try {
      final file = File(target);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode([for (final e in byPath.values) e.toJson()]),
      );
    } catch (error, stackTrace) {
      Log.w("CodexProjectStorage: failed to write $target", error, stackTrace);
    }
  }
}
