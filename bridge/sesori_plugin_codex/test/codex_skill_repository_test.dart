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
                  description: "Long description",
                  shortDescription: "Legacy short description",
                  interface: CodexSkillInterfaceDto(
                    shortDescription: "Preferred description",
                  ),
                  enabled: true,
                ),
                CodexSkillDto(
                  name: "disabled-skill",
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
                  description: "Long legacy",
                  shortDescription: "Short legacy",
                  interface: null,
                  enabled: true,
                ),
                CodexSkillDto(
                  name: "full",
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

class _StubAppServerApi extends CodexAppServerApi {
  _StubAppServerApi({required this.response})
    : super(
        client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
      );

  final CodexSkillsListResponseDto response;

  @override
  Future<CodexSkillsListResponseDto> listSkills({required String cwd}) async => response;
}
