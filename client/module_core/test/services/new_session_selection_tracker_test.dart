import "package:sesori_dart_core/src/services/models/new_session_backend_scope.dart";
import "package:sesori_dart_core/src/services/models/new_session_selection_intent.dart";
import "package:sesori_dart_core/src/services/new_session_selection_tracker.dart";
import "package:test/test.dart";

void main() {
  group("NewSessionSelectionTracker", () {
    late NewSessionSelectionTracker tracker;

    setUp(() => tracker = NewSessionSelectionTracker());

    test("read returns null when nothing saved", () {
      expect(tracker.read(pluginId: "plugin-1"), isNull);
    });

    test("write then read round-trips explicit intents per plugin", () {
      tracker.write(
        pluginId: "plugin-1",
        selection: const NewSessionSelectionIntent(
          agentName: "build",
          model: NewSessionModelIntent(providerId: "openai", modelId: "gpt-4"),
          variant: NewSessionVariantIntent(id: "fast"),
          fastMode: null,
        ),
      );
      tracker.write(
        pluginId: "plugin-2",
        selection: const NewSessionSelectionIntent(
          agentName: "plan",
          model: NewSessionModelIntent(providerId: "anthropic", modelId: "claude-3"),
          variant: NewSessionVariantIntent(id: "slow"),
          fastMode: null,
        ),
      );

      final first = tracker.read(pluginId: "plugin-1");
      expect(first?.agentName, "build");
      expect(first?.model?.providerId, "openai");
      expect(first?.model?.modelId, "gpt-4");
      expect(
        first?.variant,
        isA<NewSessionVariantIntent>().having((variant) => variant.id, "id", "fast"),
      );

      final second = tracker.read(pluginId: "plugin-2");
      expect(second?.agentName, "plan");
      expect(second?.model?.providerId, "anthropic");
      expect(second?.model?.modelId, "claude-3");
      expect(second?.variant, isA<NewSessionVariantIntent>().having((variant) => variant.id, "id", "slow"));
    });

    test("recordAgent does not write model or variant defaults", () {
      tracker.recordAgent(pluginId: "plugin-1", agentName: "build");

      final saved = tracker.read(pluginId: "plugin-1");
      expect(saved?.agentName, "build");
      expect(saved?.model, isNull);
      expect(saved?.variant, isNull);
    });

    test("recordModel does not write agent or variant defaults", () {
      tracker.recordModel(
        pluginId: "plugin-1",
        providerId: "openai",
        modelId: "gpt-4",
      );

      final saved = tracker.read(pluginId: "plugin-1");
      expect(saved?.agentName, isNull);
      expect(saved?.model?.providerId, "openai");
      expect(saved?.model?.modelId, "gpt-4");
      expect(saved?.variant, isNull);
    });

    test("recordVariant does not write agent or model defaults", () {
      tracker.recordVariant(
        pluginId: "plugin-1",
        variant: const NewSessionVariantIntent(id: "fast"),
      );

      final saved = tracker.read(pluginId: "plugin-1");
      expect(saved?.agentName, isNull);
      expect(saved?.model, isNull);
      expect(
        saved?.variant,
        isA<NewSessionVariantIntent>().having((variant) => variant.id, "id", "fast"),
      );
    });

    test("record actions preserve the other deliberate dimensions", () {
      tracker.recordFastMode(pluginId: "plugin-1", fastMode: true);
      tracker.recordAgent(pluginId: "plugin-1", agentName: "build");
      tracker.recordModel(
        pluginId: "plugin-1",
        providerId: "openai",
        modelId: "gpt-4",
      );
      tracker.recordVariant(
        pluginId: "plugin-1",
        variant: const NewSessionVariantIntent(id: "fast"),
      );

      tracker.recordAgent(pluginId: "plugin-1", agentName: "plan");
      tracker.recordModel(
        pluginId: "plugin-1",
        providerId: "anthropic",
        modelId: "claude-3",
      );
      tracker.recordVariant(
        pluginId: "plugin-1",
        variant: const NewSessionVariantIntent(id: "slow"),
      );

      final saved = tracker.read(pluginId: "plugin-1");
      expect(saved?.agentName, "plan");
      expect(saved?.model?.providerId, "anthropic");
      expect(saved?.model?.modelId, "claude-3");
      expect(saved?.variant, isA<NewSessionVariantIntent>().having((variant) => variant.id, "id", "slow"));
      expect(saved?.fastMode, isTrue);

      tracker.recordFastMode(pluginId: "plugin-1", fastMode: false);
      final afterFastMode = tracker.read(pluginId: "plugin-1");
      expect(afterFastMode?.fastMode, isFalse);
      expect(afterFastMode?.agentName, "plan");
      expect(afterFastMode?.model?.modelId, "claude-3");
      expect(afterFastMode?.variant?.id, "slow");
    });

    test("write overwrites the previous selection for a plugin", () {
      tracker.write(
        pluginId: "plugin-1",
        selection: const NewSessionSelectionIntent(
          agentName: "build",
          model: NewSessionModelIntent(providerId: "openai", modelId: "gpt-4"),
          variant: NewSessionVariantIntent(id: "slow"),
          fastMode: null,
        ),
      );
      tracker.write(
        pluginId: "plugin-1",
        selection: const NewSessionSelectionIntent(
          agentName: "plan",
          model: NewSessionModelIntent(providerId: "anthropic", modelId: "claude-3"),
          variant: NewSessionVariantIntent(id: "deep"),
          fastMode: null,
        ),
      );

      final saved = tracker.read(pluginId: "plugin-1");
      expect(saved?.agentName, "plan");
      expect(saved?.model?.providerId, "anthropic");
      expect(saved?.model?.modelId, "claude-3");
      expect(
        saved?.variant,
        isA<NewSessionVariantIntent>().having((variant) => variant.id, "id", "deep"),
      );
    });

    test("conditional clear does not remove an equal selection from a newer write", () {
      tracker.recordAgent(pluginId: "plugin-1", agentName: "build");
      final revision = tracker.currentRevision(pluginId: "plugin-1");

      tracker.recordAgent(pluginId: "plugin-1", agentName: "build");
      tracker.clearIfRevision(
        pluginId: "plugin-1",
        revision: revision,
      );

      expect(tracker.read(pluginId: "plugin-1")?.agentName, "build");
    });

    test("conditional clear removes the revision it owns", () {
      tracker.recordAgent(pluginId: "plugin-1", agentName: "build");
      final revision = tracker.currentRevision(pluginId: "plugin-1");

      tracker.clearIfRevision(
        pluginId: "plugin-1",
        revision: revision,
      );

      expect(tracker.read(pluginId: "plugin-1"), isNull);
    });

    test("stores an explicit empty selection faithfully", () {
      tracker.write(
        pluginId: "plugin-1",
        selection: const NewSessionSelectionIntent.empty(),
      );

      final saved = tracker.read(pluginId: "plugin-1");
      expect(saved, isNotNull);
      expect(saved?.agentName, isNull);
      expect(saved?.model, isNull);
      expect(saved?.variant, isNull);
    });

    test("isolates backend-local choices by plugin", () {
      tracker.recordAgent(pluginId: "plugin-a", agentName: "agent-a");
      tracker.recordAgent(pluginId: "plugin-b", agentName: "agent-b");
      final revision = tracker.currentRevision(pluginId: "plugin-a");

      tracker.clearIfRevision(pluginId: "plugin-a", revision: revision);

      expect(tracker.read(pluginId: "plugin-a"), isNull);
      expect(tracker.read(pluginId: "plugin-b")?.agentName, "agent-b");
    });

    test("clears backend-local choices when the bridge scope changes", () {
      final bridgeA = const NewSessionBackendScope.unverified(
        lastIdentifiedBridgeId: null,
      ).transitionToDiscovered(bridgeId: "bridge-a");
      tracker.applyBackendScopeTransition(transition: bridgeA);
      tracker.recordAgent(pluginId: "plugin-a", agentName: "agent-a");

      final bridgeB = bridgeA.scope.invalidate().transitionToDiscovered(bridgeId: "bridge-b");
      tracker.applyBackendScopeTransition(transition: bridgeB);

      expect(tracker.read(pluginId: "plugin-a"), isNull);
    });

    test("preserves choices when the same bridge scope is re-established", () {
      final initial = const NewSessionBackendScope.unverified(
        lastIdentifiedBridgeId: null,
      ).transitionToDiscovered(bridgeId: "bridge-a");
      tracker.applyBackendScopeTransition(transition: initial);
      tracker.recordAgent(pluginId: "plugin-a", agentName: "agent-a");

      final reconnect = initial.scope.invalidate().transitionToDiscovered(bridgeId: "bridge-a");
      tracker.applyBackendScopeTransition(transition: reconnect);

      expect(tracker.read(pluginId: "plugin-a")?.agentName, "agent-a");
    });

    test("clears choices when an unidentified bridge scope is re-established", () {
      final initial = const NewSessionBackendScope.unverified(
        lastIdentifiedBridgeId: null,
      ).transitionToDiscovered(bridgeId: null);
      tracker.applyBackendScopeTransition(transition: initial);
      tracker.recordAgent(pluginId: "plugin-a", agentName: "agent-a");

      final reconnect = initial.scope.invalidate().transitionToDiscovered(bridgeId: null);
      tracker.applyBackendScopeTransition(transition: reconnect);

      expect(tracker.read(pluginId: "plugin-a"), isNull);
    });
  });
}
