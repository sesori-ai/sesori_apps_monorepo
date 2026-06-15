import "package:sesori_dart_core/src/services/new_session_selection_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("NewSessionSelectionTracker", () {
    late NewSessionSelectionTracker tracker;

    setUp(() => tracker = NewSessionSelectionTracker());

    test("read returns null when nothing saved", () {
      expect(tracker.read(projectId: "project-1"), isNull);
    });

    test("write then read round-trips per project", () {
      tracker.write(
        projectId: "project-1",
        agent: "build",
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
      );
      tracker.write(
        projectId: "project-2",
        agent: "plan",
        agentModel: const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: null),
      );

      expect(tracker.read(projectId: "project-1")?.agent, "build");
      expect(
        tracker.read(projectId: "project-1")?.agentModel,
        const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
      );
      expect(tracker.read(projectId: "project-2")?.agent, "plan");
      expect(
        tracker.read(projectId: "project-2")?.agentModel,
        const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: null),
      );
    });

    test("write overwrites the previous selection for a project", () {
      tracker.write(
        projectId: "project-1",
        agent: "build",
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
      );
      tracker.write(
        projectId: "project-1",
        agent: "plan",
        agentModel: const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
      );

      expect(tracker.read(projectId: "project-1")?.agent, "plan");
      expect(
        tracker.read(projectId: "project-1")?.agentModel,
        const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
      );
    });

    test("clear removes a saved selection", () {
      tracker.write(
        projectId: "project-1",
        agent: "build",
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
      );
      tracker.clear(projectId: "project-1");
      expect(tracker.read(projectId: "project-1"), isNull);
    });

    test("stores null agent / model parts faithfully", () {
      tracker.write(projectId: "project-1", agent: null, agentModel: null);
      final saved = tracker.read(projectId: "project-1");
      expect(saved, isNotNull);
      expect(saved?.agent, isNull);
      expect(saved?.agentModel, isNull);
    });
  });
}
