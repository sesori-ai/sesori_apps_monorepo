@TestOn("!windows")
library;

import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

void main() {
  group("ClaudeCommandFilesApi.createProbeMirror", () {
    late Directory temporary;
    late String project;
    late String shared;
    final api = ClaudeCommandFilesApi(environment: const {});

    setUp(() {
      temporary = Directory.systemTemp.createTempSync("claude-command-files-");
      project = p.join(temporary.path, "project");
      shared = p.join(temporary.path, "shared");
      _write(p.join(project, ".claude", "commands", "plain.md"));
      _write(p.join(shared, "shared-command.md"));
      _write(p.join(shared, "shared-skill", "SKILL.md"));
    });

    tearDown(() => temporary.deleteSync(recursive: true));

    test("copies linked command files and skill folders", () async {
      Link(p.join(project, ".claude", "commands", "linked.md")).createSync(p.join(shared, "shared-command.md"));
      Link(p.join(project, ".claude", "skills", "linked-skill")).createSync(
        p.join(shared, "shared-skill"),
        recursive: true,
      );

      final mirror = await api.createProbeMirror(projectDirectory: project);
      addTearDown(() => api.deleteProbeMirror(mirror: mirror));

      expect(_files(mirror), {
        p.join(".claude", "commands", "plain.md"),
        p.join(".claude", "commands", "linked.md"),
        p.join(".claude", "skills", "linked-skill", "SKILL.md"),
      });
      expect(File(p.join(shared, "shared-command.md")).existsSync(), isTrue);
    });

    test("skips an unreadable file and a broken link and copies the rest", () async {
      final locked = p.join(project, ".claude", "commands", "locked.md");
      _write(locked);
      Process.runSync("chmod", ["000", locked]);
      Link(p.join(project, ".claude", "commands", "broken.md")).createSync(p.join(shared, "missing.md"));

      final mirror = await api.createProbeMirror(projectDirectory: project);
      addTearDown(() => api.deleteProbeMirror(mirror: mirror));

      expect(_files(mirror), {p.join(".claude", "commands", "plain.md")});
    });
  });
}

void _write(String path) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync("---\ndescription: fixture\n---\nBody\n");
}

/// The files in [mirror], relative to it.
Set<String> _files(Directory mirror) => {
  for (final entry in mirror.listSync(recursive: true))
    if (entry is File) p.relative(entry.path, from: mirror.path),
};
