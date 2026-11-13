import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/models/codex_skill_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_skill_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("maps enabled skills from the requested cwd using Codex display descriptions", () async {
    final repository = CodexSkillRepository(
      appServerApi: _StubAppServerApi(
        response: const CodexSkillsListResponseDto(
          data: [
            CodexSkillsListEntryDto(
              cwd: "/repo",
              skills: [
                CodexSkillDto(
                  name: "system-skill",
                  path: "/repo/.agents/skills/system-skill/SKILL.md",
                  description: "Long description",
                  shortDescription: "Legacy short description",
                  interface: CodexSkillInterfaceDto(
                    shortDescription: "Preferred description",
                  ),
                  enabled: true,
                ),
                CodexSkillDto(
                  name: "disabled-skill",
                  path: "/repo/.agents/skills/disabled-skill/SKILL.md",
                  description: "Disabled",
                  shortDescription: null,
                  interface: null,
                  enabled: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final commands = await repository.listCommands(cwd: "/repo");

    expect(commands, hasLength(1));
    expect(commands.single.name, "system-skill");
    expect(commands.single.description, "Preferred description");
    expect(commands.single.source, PluginCommandSource.skill);
  });

  test("finds the SKILL.md path of an enabled skill only", () async {
    final repository = CodexSkillRepository(
      appServerApi: _StubAppServerApi(
        response: const CodexSkillsListResponseDto(
          data: [
            CodexSkillsListEntryDto(
              cwd: "/repo",
              skills: [
                CodexSkillDto(
                  name: "fixture-greeter",
                  path: "/repo/.agents/skills/fixture-greeter/SKILL.md",
                  description: "Greets",
                  shortDescription: null,
                  interface: null,
                  enabled: true,
                ),
                CodexSkillDto(
                  name: "disabled-skill",
                  path: "/repo/.agents/skills/disabled-skill/SKILL.md",
                  description: "Disabled",
                  shortDescription: null,
                  interface: null,
                  enabled: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(
      await repository.findSkillPath(cwd: "/repo", name: "fixture-greeter"),
      "/repo/.agents/skills/fixture-greeter/SKILL.md",
    );
    expect(await repository.findSkillPath(cwd: "/repo", name: "disabled-skill"), isNull);
    expect(await repository.findSkillPath(cwd: "/repo", name: "missing"), isNull);
  });

  test("falls back through legacy and full descriptions", () async {
    final repository = CodexSkillRepository(
      appServerApi: _StubAppServerApi(
        response: const CodexSkillsListResponseDto(
          data: [
            CodexSkillsListEntryDto(
              cwd: "/repo",
              skills: [
                CodexSkillDto(
                  name: "legacy",
                  path: "/repo/.agents/skills/legacy/SKILL.md",
                  description: "Long legacy",
                  shortDescription: "Short legacy",
                  interface: null,
                  enabled: true,
                ),
                CodexSkillDto(
                  name: "full",
                  path: "/repo/.agents/skills/full/SKILL.md",
                  description: "Full description",
                  shortDescription: null,
                  interface: null,
                  enabled: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final commands = await repository.listCommands(cwd: "/repo");

    expect(commands.map((command) => command.description), [
      "Short legacy",
      "Full description",
    ]);
  });
}

class _StubAppServerApi({required final CodexSkillsListResponseDto response}) extends CodexAppServerApi {
  this
    : super(
        client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0", channelFactory: null, onDisconnected: null),
      );

  @override
  Future<CodexSkillsListResponseDto> listSkills({required String cwd}) async => response;
}
