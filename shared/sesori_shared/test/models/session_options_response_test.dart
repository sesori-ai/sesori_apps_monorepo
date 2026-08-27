import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("session options response round-trips all option groups", () {
    const response = SessionOptionsResponse(
      agents: Agents(
        agents: [
          AgentInfo(
            name: "build",
            description: "Builds the requested change",
            model: AgentModel(modelID: "gpt-5", providerID: "openai", variant: "high"),
            mode: AgentMode.primary,
          ),
        ],
      ),
      providers: ProviderListResponse(
        items: [
          ProviderInfo(
            id: "openai",
            name: "OpenAI",
            models: {},
            defaultModelID: "gpt-5",
          ),
        ],
        connectedOnly: true,
      ),
      commands: CommandListResponse(
        items: [
          CommandInfo(
            name: "review",
            template: null,
            hints: null,
            description: "Reviews the current changes",
            agent: "build",
            model: null,
            provider: null,
            source: CommandSource.command,
            subtask: false,
          ),
        ],
      ),
      lastUsedPromptDefaults: SessionPromptDefaults(
        agent: "build",
        model: AgentModel(providerID: "openai", modelID: "gpt-5", variant: "high"),
      ),
    );

    final json = response.toJson();

    expect(SessionOptionsResponse.fromJson(json), response);
    expect(json.keys, containsAllInOrder(["agents", "providers", "commands"]));
    // A bridge that predates the staleness signal simply never reports one.
    expect(SessionOptionsResponse.fromJson({...json}..remove("stale")).stale, isFalse);
    // A bridge that predates remembered new-session defaults has no stored
    // selection to apply.
    expect(
      SessionOptionsResponse.fromJson({...json}..remove("lastUsedPromptDefaults")).lastUsedPromptDefaults,
      isNull,
    );
  });

  test("session options errors round-trip known codes", () {
    for (final code in SessionOptionsErrorCode.values) {
      final response = SessionOptionsErrorResponse(code: code);

      expect(SessionOptionsErrorResponse.fromJson(response.toJson()), response);
    }
  });

  test("session options errors map unknown codes to unknown", () {
    final response = SessionOptionsErrorResponse.fromJson(const {"code": "futureFailure"});

    expect(response.code, SessionOptionsErrorCode.unknown);
  });
}
