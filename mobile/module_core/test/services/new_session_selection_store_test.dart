import "package:sesori_dart_core/src/services/new_session_selection_store.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("NewSessionSelectionStore", () {
    late NewSessionSelectionStore store;

    setUp(() => store = NewSessionSelectionStore());

    test("read returns null when nothing saved", () {
      expect(store.read("project-1"), isNull);
    });

    test("write then read round-trips per project", () {
      store.write(
        "project-1",
        agent: "build",
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
      );
      store.write(
        "project-2",
        agent: "plan",
        agentModel: const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: null),
      );

      expect(store.read("project-1")?.agent, "build");
      expect(
        store.read("project-1")?.agentModel,
        const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
      );
      expect(store.read("project-2")?.agent, "plan");
      expect(
        store.read("project-2")?.agentModel,
        const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: null),
      );
    });

    test("write overwrites the previous selection for a project", () {
      store.write(
        "project-1",
        agent: "build",
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
      );
      store.write(
        "project-1",
        agent: "plan",
        agentModel: const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
      );

      expect(store.read("project-1")?.agent, "plan");
      expect(
        store.read("project-1")?.agentModel,
        const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
      );
    });

    test("clear removes a saved selection", () {
      store.write(
        "project-1",
        agent: "build",
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
      );
      store.clear("project-1");
      expect(store.read("project-1"), isNull);
    });

    test("stores null agent / model parts faithfully", () {
      store.write("project-1", agent: null, agentModel: null);
      final saved = store.read("project-1");
      expect(saved, isNotNull);
      expect(saved?.agent, isNull);
      expect(saved?.agentModel, isNull);
    });
  });
}
