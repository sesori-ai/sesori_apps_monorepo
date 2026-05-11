import "dart:io";

import "package:path/path.dart" as p;

/// A single codex skill discovered on disk.
class CodexSkill {
  const CodexSkill({
    required this.name,
    required this.description,
    required this.path,
    required this.source,
  });

  final String name;
  final String description;
  final String path;
  final CodexSkillSource source;
}

enum CodexSkillSource { user, project }

/// Read-only enumerator for codex skills.
///
/// Codex stores skills as `<dir>/<slug>/SKILL.md` with a YAML frontmatter
/// block carrying `name:` and `description:`. Two locations are scanned:
///   - User-level: `$CODEX_HOME/skills` (defaults to `~/.codex/skills`).
///   - Project-local: `<projectCwd>/.codex/skills`.
///
/// Project-local skills win when names collide.
class CodexSkillReader {
  CodexSkillReader({Map<String, String>? environment, String? projectCwd})
    : _environment = environment ?? Platform.environment,
      _projectCwd = projectCwd;

  final Map<String, String> _environment;
  final String? _projectCwd;

  String? get _codexHome {
    final explicit = _environment["CODEX_HOME"];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final home = _environment["HOME"] ?? _environment["USERPROFILE"];
    if (home == null || home.isEmpty) return null;
    return p.join(home, ".codex");
  }

  List<CodexSkill> list() {
    final out = <String, CodexSkill>{};
    final userRoot = _codexHome;
    if (userRoot != null) {
      _scan(p.join(userRoot, "skills"), CodexSkillSource.user, out);
    }
    final projectCwd = _projectCwd;
    if (projectCwd != null) {
      _scan(
        p.join(projectCwd, ".codex", "skills"),
        CodexSkillSource.project,
        out,
      );
    }
    final list = out.values.toList(growable: false);
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void _scan(
    String directory,
    CodexSkillSource source,
    Map<String, CodexSkill> sink,
  ) {
    final dir = Directory(directory);
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      final skillFile = File(p.join(entity.path, "SKILL.md"));
      if (!skillFile.existsSync()) continue;
      final skill = _parseSkill(entity.path, skillFile, source);
      if (skill != null) {
        // Project skills override user skills on name collision.
        final existing = sink[skill.name];
        if (existing == null || source == CodexSkillSource.project) {
          sink[skill.name] = skill;
        }
      }
    }
  }

  CodexSkill? _parseSkill(
    String dirPath,
    File skillFile,
    CodexSkillSource source,
  ) {
    final lines = skillFile.readAsLinesSync();
    if (lines.isEmpty || lines.first.trim() != "---") return null;

    String? name;
    String? description;
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim() == "---") break;
      final colon = line.indexOf(":");
      if (colon < 0) continue;
      final key = line.substring(0, colon).trim();
      final value = line.substring(colon + 1).trim();
      if (key == "name") {
        name = _stripQuotes(value);
      } else if (key == "description") {
        description = _stripQuotes(value);
      }
    }

    // Fall back to the directory name as the skill name if frontmatter
    // didn't supply one.
    final resolvedName = name ?? p.basename(dirPath);
    return CodexSkill(
      name: resolvedName,
      description: description ?? "",
      path: skillFile.path,
      source: source,
    );
  }

  static String _stripQuotes(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }
}
