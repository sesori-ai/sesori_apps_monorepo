import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

void main() {
  group("CodexSkillReader", () {
    late Directory codexHome;
    late Directory projectCwd;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-skills-");
      projectCwd = Directory.systemTemp.createTempSync("codex-project-");
    });

    tearDown(() {
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {}
      try {
        projectCwd.deleteSync(recursive: true);
      } catch (_) {}
    });

    test("lists user-level skills with frontmatter", () {
      _writeSkill(
        codexHome,
        "skills/ralph/SKILL.md",
        name: "ralph",
        description: "Persistence loop until task completion",
      );
      _writeSkill(
        codexHome,
        "skills/plan/SKILL.md",
        name: "plan",
        description: "Strategic planning workflow",
      );

      final reader = CodexSkillReader(
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: projectCwd.path,
      );

      final skills = reader.list();
      expect(skills.map((s) => s.name).toList(), equals(["plan", "ralph"]));
      expect(skills.first.description, equals("Strategic planning workflow"));
      expect(skills.first.source, equals(CodexSkillSource.user));
    });

    test("project-local skills override user skills on name collision", () {
      _writeSkill(
        codexHome,
        "skills/plan/SKILL.md",
        name: "plan",
        description: "user-level",
      );
      _writeSkill(
        projectCwd,
        ".codex/skills/plan/SKILL.md",
        name: "plan",
        description: "project-local override",
      );

      final reader = CodexSkillReader(
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: projectCwd.path,
      );

      final skills = reader.list();
      expect(skills, hasLength(1));
      expect(skills.single.description, equals("project-local override"));
      expect(skills.single.source, equals(CodexSkillSource.project));
    });

    test("falls back to directory name when frontmatter has no name", () {
      _writeSkill(
        codexHome,
        "skills/no-name/SKILL.md",
        name: null,
        description: "just-a-description",
      );

      final reader = CodexSkillReader(
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: projectCwd.path,
      );

      final skills = reader.list();
      expect(skills.single.name, equals("no-name"));
      expect(skills.single.description, equals("just-a-description"));
    });

    test(
      "directories without SKILL.md and files without frontmatter are ignored",
      () {
        Directory(
          p.join(codexHome.path, "skills", "broken"),
        ).createSync(recursive: true);
        _writeFile(
          codexHome,
          "skills/no-frontmatter/SKILL.md",
          "Just regular markdown without YAML",
        );

        final reader = CodexSkillReader(
          environment: {"CODEX_HOME": codexHome.path},
          projectCwd: projectCwd.path,
        );

        expect(reader.list(), isEmpty);
      },
    );
  });
}

void _writeSkill(
  Directory root,
  String relPath, {
  required String? name,
  required String description,
}) {
  final lines = <String>["---"];
  if (name != null) lines.add("name: $name");
  lines.add("description: $description");
  lines.add("---");
  lines.add("");
  lines.add("Body of the skill.");
  _writeFile(root, relPath, lines.join("\n"));
}

void _writeFile(Directory root, String relPath, String contents) {
  final full = p.join(root.path, relPath);
  Directory(p.dirname(full)).createSync(recursive: true);
  File(full).writeAsStringSync(contents);
}
