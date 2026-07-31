import "package:sesori_dart_core/src/services/models/new_session_backend_scope.dart";
import "package:sesori_dart_core/src/services/models/new_session_selection_intent.dart";
import "package:sesori_dart_core/src/services/new_session_selection_tracker.dart";
import "package:test/test.dart";

void main() {
  group("NewSessionSelectionTracker", () {
    late NewSessionSelectionTracker tracker;

    setUp(() => tracker = NewSessionSelectionTracker());

    test("read returns null when nothing saved", () {
      expect(tracker.read(projectId: "project-1", pluginId: "plugin-1"), isNull);
    });

    test("write then read round-trips explicit intents per project", () {
      tracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        selection: const NewSessionSelectionIntent(
          agentName: "build",
          model: NewSessionModelIntent(providerId: "openai", modelId: "gpt-4"),
          variant: NewSessionNamedVariantIntent(id: "fast"),
        ),
      );
      tracker.write(
        projectId: "project-2",
        pluginId: "plugin-1",
        selection: const NewSessionSelectionIntent(
          agentName: "plan",
          model: NewSessionModelIntent(providerId: "anthropic", modelId: "claude-3"),
          variant: NewSessionDefaultVariantIntent(),
        ),
      );

      final first = tracker.read(projectId: "project-1", pluginId: "plugin-1");
      expect(first?.agentName, "build");
      expect(first?.model?.providerId, "openai");
      expect(first?.model?.modelId, "gpt-4");
      expect(
        first?.variant,
        isA<NewSessionNamedVariantIntent>().having((variant) => variant.id, "id", "fast"),
      );

      final second = tracker.read(projectId: "project-2", pluginId: "plugin-1");
      expect(second?.agentName, "plan");
      expect(second?.model?.providerId, "anthropic");
      expect(second?.model?.modelId, "claude-3");
      expect(second?.variant, isA<NewSessionDefaultVariantIntent>());
    });

    test("recordAgent does not write model or variant defaults", () {
      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "build");

      final saved = tracker.read(projectId: "project-1", pluginId: "plugin-1");
      expect(saved?.agentName, "build");
      expect(saved?.model, isNull);
      expect(saved?.variant, isNull);
    });

    test("recordModel does not write agent or variant defaults", () {
      tracker.recordModel(
        projectId: "project-1",
        pluginId: "plugin-1",
        providerId: "openai",
        modelId: "gpt-4",
      );

      final saved = tracker.read(projectId: "project-1", pluginId: "plugin-1");
      expect(saved?.agentName, isNull);
      expect(saved?.model?.providerId, "openai");
      expect(saved?.model?.modelId, "gpt-4");
      expect(saved?.variant, isNull);
    });

    test("recordVariant does not write agent or model defaults", () {
      tracker.recordVariant(
        projectId: "project-1",
        pluginId: "plugin-1",
        variant: const NewSessionNamedVariantIntent(id: "fast"),
      );

      final saved = tracker.read(projectId: "project-1", pluginId: "plugin-1");
      expect(saved?.agentName, isNull);
      expect(saved?.model, isNull);
      expect(
        saved?.variant,
        isA<NewSessionNamedVariantIntent>().having((variant) => variant.id, "id", "fast"),
      );
    });

    test("record actions preserve the other deliberate dimensions", () {
      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "build");
      tracker.recordModel(
        projectId: "project-1",
        pluginId: "plugin-1",
        providerId: "openai",
        modelId: "gpt-4",
      );
      tracker.recordVariant(
        projectId: "project-1",
        pluginId: "plugin-1",
        variant: const NewSessionNamedVariantIntent(id: "fast"),
      );

      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "plan");
      tracker.recordModel(
        projectId: "project-1",
        pluginId: "plugin-1",
        providerId: "anthropic",
        modelId: "claude-3",
      );
      tracker.recordVariant(
        projectId: "project-1",
        pluginId: "plugin-1",
        variant: const NewSessionDefaultVariantIntent(),
      );

      final saved = tracker.read(projectId: "project-1", pluginId: "plugin-1");
      expect(saved?.agentName, "plan");
      expect(saved?.model?.providerId, "anthropic");
      expect(saved?.model?.modelId, "claude-3");
      expect(saved?.variant, isA<NewSessionDefaultVariantIntent>());
    });

    test("write overwrites the previous selection for a project", () {
      tracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        selection: const NewSessionSelectionIntent(
          agentName: "build",
          model: NewSessionModelIntent(providerId: "openai", modelId: "gpt-4"),
          variant: NewSessionDefaultVariantIntent(),
        ),
      );
      tracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        selection: const NewSessionSelectionIntent(
          agentName: "plan",
          model: NewSessionModelIntent(providerId: "anthropic", modelId: "claude-3"),
          variant: NewSessionNamedVariantIntent(id: "deep"),
        ),
      );

      final saved = tracker.read(projectId: "project-1", pluginId: "plugin-1");
      expect(saved?.agentName, "plan");
      expect(saved?.model?.providerId, "anthropic");
      expect(saved?.model?.modelId, "claude-3");
      expect(
        saved?.variant,
        isA<NewSessionNamedVariantIntent>().having((variant) => variant.id, "id", "deep"),
      );
    });

    test("conditional clear does not remove an equal selection from a newer write", () {
      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "build");
      final revision = tracker.currentRevision(projectId: "project-1", pluginId: "plugin-1");

      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "build");
      tracker.clearIfRevision(
        projectId: "project-1",
        pluginId: "plugin-1",
        revision: revision,
      );

      expect(tracker.read(projectId: "project-1", pluginId: "plugin-1")?.agentName, "build");
    });

    test("conditional clear removes the revision it owns", () {
      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "build");
      final revision = tracker.currentRevision(projectId: "project-1", pluginId: "plugin-1");

      tracker.clearIfRevision(
        projectId: "project-1",
        pluginId: "plugin-1",
        revision: revision,
      );

      expect(tracker.read(projectId: "project-1", pluginId: "plugin-1"), isNull);
    });

    test("clear removes a saved selection", () {
      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "build");
      tracker.clear(projectId: "project-1", pluginId: "plugin-1");

      expect(tracker.read(projectId: "project-1", pluginId: "plugin-1"), isNull);
    });

    test("stores an explicit empty selection faithfully", () {
      tracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        selection: const NewSessionSelectionIntent.empty(),
      );

      final saved = tracker.read(projectId: "project-1", pluginId: "plugin-1");
      expect(saved, isNotNull);
      expect(saved?.agentName, isNull);
      expect(saved?.model, isNull);
      expect(saved?.variant, isNull);
    });

    test("isolates backend-local choices by project and plugin", () {
      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-a", agentName: "agent-a");
      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-b", agentName: "agent-b");

      expect(tracker.read(projectId: "project-1", pluginId: "plugin-a")?.agentName, "agent-a");
      expect(tracker.read(projectId: "project-1", pluginId: "plugin-b")?.agentName, "agent-b");

      tracker.clear(projectId: "project-1", pluginId: "plugin-a");

      expect(tracker.read(projectId: "project-1", pluginId: "plugin-a"), isNull);
      expect(tracker.read(projectId: "project-1", pluginId: "plugin-b")?.agentName, "agent-b");
    });

    test("clears backend-local choices when the bridge scope changes", () {
      final bridgeA = const NewSessionBackendScope.unverified(
        lastIdentifiedBridgeId: null,
      ).transitionToDiscovered(bridgeId: "bridge-a");
      tracker.applyBackendScopeTransition(transition: bridgeA);
      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-a", agentName: "agent-a");

      final bridgeB = bridgeA.scope.invalidate().transitionToDiscovered(bridgeId: "bridge-b");
      tracker.applyBackendScopeTransition(transition: bridgeB);

      expect(tracker.read(projectId: "project-1", pluginId: "plugin-a"), isNull);
    });

    test("preserves choices when the same bridge scope is re-established", () {
      final initial = const NewSessionBackendScope.unverified(
        lastIdentifiedBridgeId: null,
      ).transitionToDiscovered(bridgeId: "bridge-a");
      tracker.applyBackendScopeTransition(transition: initial);
      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-a", agentName: "agent-a");

      final reconnect = initial.scope.invalidate().transitionToDiscovered(bridgeId: "bridge-a");
      tracker.applyBackendScopeTransition(transition: reconnect);

      expect(tracker.read(projectId: "project-1", pluginId: "plugin-a")?.agentName, "agent-a");
    });

    test("clears choices when an unidentified bridge scope is re-established", () {
      final initial = const NewSessionBackendScope.unverified(
        lastIdentifiedBridgeId: null,
      ).transitionToDiscovered(bridgeId: null);
      tracker.applyBackendScopeTransition(transition: initial);
      tracker.recordAgent(projectId: "project-1", pluginId: "plugin-a", agentName: "agent-a");

      final reconnect = initial.scope.invalidate().transitionToDiscovered(bridgeId: null);
      tracker.applyBackendScopeTransition(transition: reconnect);

      expect(tracker.read(projectId: "project-1", pluginId: "plugin-a"), isNull);
    });
  });
}
