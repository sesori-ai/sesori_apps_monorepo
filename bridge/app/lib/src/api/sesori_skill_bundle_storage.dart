import "dart:convert";
import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show SesoriSkillBundle;
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGuide;

/// The folder of skills written from tool-group guides
/// (`sesoriAgentSkillsDirectory()`), in the two layouts of
/// [SesoriSkillBundle]. Each write regenerates it whole, so it holds no
/// state of its own.
class SesoriSkillBundleStorage({required final String _directoryPath}) {
  SesoriSkillBundle? _current;

  /// The bundle the last [write] produced, or null before the first one, after
  /// one with no guides, or after one that failed.
  SesoriSkillBundle? get current => _current;

  /// Replaces the folder with one skill per guide in [guides]; with none,
  /// removes it.
  void write({required List<SesoriToolGuide> guides}) {
    _current = null;
    final root = Directory(_directoryPath);
    if (root.existsSync()) root.deleteSync(recursive: true);
    if (guides.isEmpty) return;

    final pluginRoot = path.join(_directoryPath, "claude-plugin");
    final skillsRoot = path.join(_directoryPath, "skills");
    _writeFile(
      filePath: path.join(pluginRoot, ".claude-plugin", "plugin.json"),
      contents: jsonEncode({
        "name": "sesori",
        "description": "How-tos for Sesori's agent tools, written by the Sesori bridge.",
      }),
    );
    for (final guide in guides) {
      _writeFile(
        filePath: path.join(pluginRoot, "skills", guide.name, "SKILL.md"),
        contents: _skill(name: guide.name, guide: guide),
      );
      _writeFile(
        filePath: path.join(skillsRoot, "sesori-${guide.name}", "SKILL.md"),
        contents: _skill(name: "sesori-${guide.name}", guide: guide),
      );
    }
    _current = SesoriSkillBundle(pluginRoot: pluginRoot, skillsRoot: skillsRoot);
  }

  /// A JSON string is a valid YAML double-quoted scalar, so the description
  /// needs no YAML escaping of its own.
  static String _skill({required String name, required SesoriToolGuide guide}) =>
      "---\nname: $name\ndescription: ${jsonEncode(guide.whenToUse)}\n---\n\n${guide.body}";

  static void _writeFile({required String filePath, required String contents}) {
    File(filePath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(contents);
  }
}
