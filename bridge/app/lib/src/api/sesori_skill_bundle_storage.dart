import "dart:convert";
import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show SesoriSkillBundle;
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGuide;

/// The bridge's own skill folder. Each bridge data directory has one, since
/// its contents follow that bridge's settings.
String sesoriSkillBundleDirectoryPath({required String dataDirectory}) => path.join(dataDirectory, "agent-skills");

/// The folder of skills written from tool-group guides, in the two layouts of
/// [SesoriSkillBundle]. Each write regenerates it whole.
class SesoriSkillBundleStorage({required final String _directoryPath}) {
  /// Replaces the folder with one skill per guide in [guides] and returns
  /// where they are; with none, removes it and returns null.
  SesoriSkillBundle? write({required List<SesoriToolGuide> guides}) {
    final root = Directory(_directoryPath);
    if (root.existsSync()) root.deleteSync(recursive: true);
    if (guides.isEmpty) return null;

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
    return SesoriSkillBundle(pluginRoot: pluginRoot, skillsRoot: skillsRoot);
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
