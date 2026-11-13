import "dart:io";

import "package:path/path.dart" as p;

import "../foundation/claude_config_directory.dart";
import "models/claude_backend_catalog_dto.dart";

/// The command and skill entries the plugin reads from disk instead of from a
/// probe that loaded project settings.
final class const ClaudeCommandFiles({
  required final List<ClaudeCommandDto> projectCommands,
  required final List<ClaudeCommandDto> projectSkills,
  required final Set<String> userSkillNames,
});

/// Layer-1 reader for the project's `.claude/commands` and `.claude/skills`
/// and the user's skill folder. It only reads names and frontmatter: a catalog
/// probe skips project settings, whose helper commands would run at startup,
/// so it no longer lists the project's entries itself.
class ClaudeCommandFilesApi({required Map<String, String> environment}) {
  static const String _skillFile = "SKILL.md";
  static const String _projectSuffix = " (project)";
  static final RegExp _frontmatterDelimiter = RegExp(r"^---\s*$");
  static final RegExp _field = RegExp(r"^([A-Za-z-]+):\s*(.*?)\s*$");
  static final RegExp _quotes = RegExp(r"""^["']|["']$""");

  final Map<String, String> _environment = Map.unmodifiable(environment);

  /// Named the way Claude Code 2.1.323 names them (verified live): a command
  /// by its path under `commands` with `:` between folders, a skill by its
  /// `SKILL.md` frontmatter `name`, else its folder. A description is the
  /// frontmatter `description`, else the first body line, with Claude's
  /// ` (project)` suffix. An entry that is not user-invocable is skipped. A
  /// missing folder or `SKILL.md` contributes nothing; any other filesystem
  /// failure throws.
  Future<ClaudeCommandFiles> read({required String projectDirectory}) async {
    final project = p.join(projectDirectory, ".claude");
    final configDirectory = claudeConfigDirectory(environment: _environment);
    return ClaudeCommandFiles(
      projectCommands: await _commandsIn(root: p.join(project, "commands")),
      projectSkills: await _skillsIn(root: p.join(project, "skills")),
      userSkillNames: {
        if (configDirectory != null)
          for (final skill in await _skillsIn(root: p.join(configDirectory, "skills"))) ?skill.name,
      },
    );
  }

  Future<List<ClaudeCommandDto>> _commandsIn({required String root}) async {
    final List<File> files;
    try {
      files = await Directory(root)
          .list(recursive: true, followLinks: true)
          .where((entry) => entry is File && p.extension(entry.path) == ".md")
          .cast<File>()
          .toList();
    } on PathNotFoundException {
      return const [];
    }
    return [
      for (final file in files)
        ?_entry(
          defaultName: p.split(p.withoutExtension(p.relative(file.path, from: root))).join(":"),
          lines: await file.readAsLines(),
          nameFromFrontmatter: false,
        ),
    ];
  }

  Future<List<ClaudeCommandDto>> _skillsIn({required String root}) async {
    final List<Directory> folders;
    try {
      folders = await Directory(root)
          .list(followLinks: true)
          .where((entry) => entry is Directory)
          .cast<Directory>()
          .toList();
    } on PathNotFoundException {
      return const [];
    }
    return [for (final folder in folders) ?await _skill(folder: folder)];
  }

  Future<ClaudeCommandDto?> _skill({required Directory folder}) async {
    final List<String> lines;
    try {
      lines = await File(p.join(folder.path, _skillFile)).readAsLines();
    } on PathNotFoundException {
      return null;
    }
    return _entry(defaultName: p.basename(folder.path), lines: lines, nameFromFrontmatter: true);
  }

  /// The entry, or null when its frontmatter says `user-invocable: false`:
  /// Claude then leaves it out of its own list (verified live with 2.1.323,
  /// for commands and skills alike), as `/name` cannot run it.
  ClaudeCommandDto? _entry({
    required String defaultName,
    required List<String> lines,
    required bool nameFromFrontmatter,
  }) {
    final fields = <String, String>{};
    var body = lines;
    if (lines.isNotEmpty && _frontmatterDelimiter.hasMatch(lines.first)) {
      final end = lines.indexWhere(_frontmatterDelimiter.hasMatch, 1);
      if (end > 0) {
        for (final line in lines.sublist(1, end)) {
          if (_field.firstMatch(line) case final match?) {
            final value = (match.group(2) ?? "").replaceAll(_quotes, "");
            if (value.isNotEmpty) fields[match.group(1) ?? ""] = value;
          }
        }
        body = lines.sublist(end + 1);
      }
    }
    if (fields["user-invocable"]?.toLowerCase() == "false") return null;
    final description = fields["description"] ?? _firstText(lines: body);
    return ClaudeCommandDto(
      name: nameFromFrontmatter ? fields["name"] ?? defaultName : defaultName,
      description: description == null ? null : "$description$_projectSuffix",
      argumentHint: fields["argument-hint"],
    );
  }

  String? _firstText({required List<String> lines}) {
    for (final line in lines) {
      final text = line.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
