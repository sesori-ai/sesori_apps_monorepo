import "dart:convert";
import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_bridge/src/api/sesori_skill_bundle_storage.dart";
import "package:sesori_bridge/src/listeners/sesori_skill_bundle_listener.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/repositories/models/sesori_tool_group_ids.dart";
import "package:sesori_bridge/src/repositories/sesori_skill_bundle_repository.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart";
import "package:test/test.dart";

import "../helpers/in_memory_bridge_settings_api.dart";

void main() {
  const guide = SesoriToolGuide(
    name: "pr-monitor",
    whenToUse: "Use after you open a PR: when a [PR Monitor] message arrives.",
    body: "# How-to\n\nWatch it.\n",
  );

  late Directory directory;
  late BridgeSettingsRepository settings;
  late SesoriSkillBundleRepository skillBundles;
  late SesoriSkillBundleListener listener;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync("sesori-agent-skills-test-");
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    settings = BridgeSettingsRepository(defaultEditorApi: null, api: InMemoryBridgeSettingsApi(config: "{}"));
    await settings.loadSettings();
    skillBundles = SesoriSkillBundleRepository(
      storage: SesoriSkillBundleStorage(directoryPath: path.join(directory.path, "agent-skills")),
    );
    listener = SesoriSkillBundleListener(
      settings: settings,
      groups: [
        _FakeGroup(id: SesoriToolGroupIds.tasks, guide: null),
        _FakeGroup(id: SesoriToolGroupIds.prMonitor, guide: guide),
      ],
      skillBundles: skillBundles,
    );
    addTearDown(listener.dispose);
  });

  test("writes each enabled guide as a Claude plugin skill and a plain skill", () {
    listener.start();

    final bundle = skillBundles.current ?? fail("the PR monitor has a guide and is on");
    final manifest = jsonDecode(File(path.join(bundle.pluginRoot, ".claude-plugin", "plugin.json")).readAsStringSync());
    expect(manifest, containsPair("name", "sesori"));
    final pluginSkill = File(path.join(bundle.pluginRoot, "skills", "pr-monitor", "SKILL.md")).readAsStringSync();
    expect(
      pluginSkill,
      '---\nname: pr-monitor\ndescription: "Use after you open a PR: when a [PR Monitor] message arrives."\n---\n\n'
      "# How-to\n\nWatch it.\n",
    );
    final plainSkill = File(path.join(bundle.skillsRoot, "sesori-pr-monitor", "SKILL.md")).readAsStringSync();
    expect(plainSkill, startsWith("---\nname: sesori-pr-monitor\n"));
    expect(Directory(bundle.skillsRoot).listSync().map((entry) => path.basename(entry.path)), ["sesori-pr-monitor"]);
  });

  test("removes the bundle while the group is off and writes it again once it is back on", () async {
    listener.start();
    final bundle = skillBundles.current ?? fail("the PR monitor starts on");

    await settings.updateToolGroup(id: SesoriToolGroupIds.prMonitor, enabled: false);
    await pumpEventQueue();
    expect(skillBundles.current, isNull);
    expect(Directory(bundle.pluginRoot).existsSync(), isFalse);

    await settings.updateToolGroup(id: SesoriToolGroupIds.prMonitor, enabled: true);
    await pumpEventQueue();
    expect(skillBundles.current, isNotNull);
    expect(File(path.join(bundle.skillsRoot, "sesori-pr-monitor", "SKILL.md")).existsSync(), isTrue);
  });

  test("writes no bundle while agent tools are off", () async {
    await settings.updateAgentTools(enabled: false);

    listener.start();

    expect(skillBundles.current, isNull);
    expect(directory.listSync(), isEmpty);
  });
}

class _FakeGroup({@override required final SesoriToolGroupId id, @override required final SesoriToolGuide? guide})
    implements SesoriToolGroup {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
