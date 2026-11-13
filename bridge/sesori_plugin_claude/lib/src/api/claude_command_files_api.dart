import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginWorkingDirectoryMissingException;

import "../foundation/claude_config_directory.dart";

/// Layer-1 owner of the project files a catalog probe needs: the mirror it runs
/// in, and the skill names that label its list.
class ClaudeCommandFilesApi({required Map<String, String> environment}) {
  static const List<String> _mirroredFolders = ["commands", "skills"];
  static const String _skillFile = "SKILL.md";
  static final RegExp _frontmatterDelimiter = RegExp(r"^---\s*$");
  static final RegExp _nameEntry = RegExp(r"^name:\s*(.+?)\s*$");

  final Map<String, String> _environment = Map.unmodifiable(environment);

  /// Creates a directory whose `.claude` holds only links to
  /// [projectDirectory]'s `.claude/commands` and `.claude/skills`. A probe
  /// started there lists the project's commands and skills by Claude's own
  /// rules, but loads none of the project's settings, `.mcp.json` or
  /// `CLAUDE.md`, so nothing the project controls runs. Verified live with
  /// Claude Code 2.1.323. The caller deletes it with [deleteProbeMirror].
  Future<Directory> createProbeMirror({required String projectDirectory}) async {
    if (!Directory(projectDirectory).existsSync()) {
      throw PluginWorkingDirectoryMissingException(
        operation: "mirror Claude project commands",
        path: projectDirectory,
        cause: null,
      );
    }
    final mirror = await Directory.systemTemp.createTemp("sesori-claude-catalog-");
    try {
      final claude = await Directory(p.join(mirror.path, ".claude")).create();
      for (final folder in _mirroredFolders) {
        await Link(p.join(claude.path, folder)).create(p.join(projectDirectory, ".claude", folder));
      }
      return mirror;
    } on Object {
      await deleteProbeMirror(mirror: mirror);
      rethrow;
    }
  }

  /// Deletes a [createProbeMirror] directory. Its links are removed, never
  /// followed.
  Future<void> deleteProbeMirror({required Directory mirror}) => mirror.delete(recursive: true);

  /// The names of the skills in [projectDirectory]'s `.claude/skills` and in
  /// the user's `<config dir>/skills`.
  ///
  /// Claude names a skill by its `SKILL.md` frontmatter `name`, else by its
  /// folder (verified live with Claude Code 2.1.323). A missing folder or
  /// `SKILL.md` contributes no name; any other filesystem failure throws.
  Future<Set<String>> readSkillNames({required String projectDirectory}) async {
    final configDirectory = claudeConfigDirectory(environment: _environment);
    final roots = [
      p.join(projectDirectory, ".claude", "skills"),
      if (configDirectory != null) p.join(configDirectory, "skills"),
    ];
    return {
      for (final root in roots) ...await _skillNamesIn(root: root),
    };
  }

  Future<List<String>> _skillNamesIn({required String root}) async {
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
    return [
      for (final folder in folders) ?await _skillName(folder: folder),
    ];
  }

  /// The skill [folder] holds, or null when it has no `SKILL.md`.
  Future<String?> _skillName({required Directory folder}) async {
    try {
      final lines = await File(p.join(folder.path, _skillFile)).readAsLines();
      return _frontmatterName(lines: lines) ?? p.basename(folder.path);
    } on PathNotFoundException {
      return null;
    }
  }

  String? _frontmatterName({required List<String> lines}) {
    if (lines.isEmpty || !_frontmatterDelimiter.hasMatch(lines.first)) return null;
    for (final line in lines.skip(1)) {
      if (_frontmatterDelimiter.hasMatch(line)) return null;
      if (_nameEntry.firstMatch(line)?.group(1) case final value?) {
        final name = value.replaceAll(RegExp(r"""^["']|["']$"""), "");
        return name.isEmpty ? null : name;
      }
    }
    return null;
  }
}
