import "package:cursor_plugin/src/models/cursor_catalog_models.dart";
import "package:cursor_plugin/src/trackers/cursor_catalog_tracker.dart";
import "package:test/test.dart";

void main() {
  group("CursorCatalogTracker", () {
    late CursorCatalogTracker tracker;

    setUp(() {
      tracker = CursorCatalogTracker();
    });

    test("owns catalog defaults, selections, and provisional variants", () {
      final capture = tracker.applySnapshot(
        snapshot: _snapshot(
          loadedModelId: "gpt-5.4",
          loadedModeId: "agent",
          includeThoughtLevel: true,
        ),
        fromNewSession: true,
        thoughtLevelModelId: null,
        captureThoughtLevelDefault: true,
      );

      expect(capture.loadedModelId, "gpt-5.4");
      expect(tracker.currentModelId, "gpt-5.4");
      expect(tracker.defaultModeId, "agent");
      expect(tracker.isComplete, isTrue);
      expect(tracker.hasModel(modelId: "sonnet-4.6"), isTrue);
      expect(tracker.hasModeOption(modeId: "plan"), isTrue);
      expect(tracker.resolveModeId(agent: "Plan"), "plan");
      expect(tracker.variantsForModel(modelId: "sonnet-4.6"), ["medium", "low", "high"]);
      expect(tracker.thoughtLevelForModel(modelId: "gpt-5.4")?.defaultValue, "medium");
    });

    test("loaded sessions do not replace new-session model or mode defaults", () {
      tracker.applySnapshot(
        snapshot: _snapshot(
          loadedModelId: "gpt-5.4",
          loadedModeId: "agent",
          includeThoughtLevel: true,
        ),
        fromNewSession: true,
        thoughtLevelModelId: null,
        captureThoughtLevelDefault: true,
      );

      tracker.applySnapshot(
        snapshot: _snapshot(
          loadedModelId: "sonnet-4.6",
          loadedModeId: "plan",
          includeThoughtLevel: false,
        ),
        fromNewSession: false,
        thoughtLevelModelId: null,
        captureThoughtLevelDefault: false,
      );

      expect(tracker.currentModelId, "gpt-5.4");
      expect(tracker.defaultModeId, "agent");
    });

    test("loaded historical effort does not become a new-session default", () {
      tracker.applySnapshot(
        snapshot: _snapshot(
          loadedModelId: "sonnet-4.6",
          loadedModeId: "plan",
          includeThoughtLevel: true,
        ),
        fromNewSession: false,
        thoughtLevelModelId: null,
        captureThoughtLevelDefault: false,
      );

      expect(
        tracker.thoughtLevelForModel(modelId: "sonnet-4.6")?.defaultValue,
        isNull,
      );
      expect(
        tracker.variantsForModel(modelId: "sonnet-4.6"),
        ["medium", "low", "high"],
      );
    });

    test("falls back when a fresh session reports an unknown model", () {
      tracker.applySnapshot(
        snapshot: _snapshot(
          loadedModelId: "unknown",
          loadedModeId: "agent",
          includeThoughtLevel: false,
        ),
        fromNewSession: true,
        thoughtLevelModelId: null,
        captureThoughtLevelDefault: true,
      );

      expect(tracker.currentModelId, "gpt-5.4");
    });
  });
}

CursorCatalogSnapshot _snapshot({
  required String loadedModelId,
  required String loadedModeId,
  required bool includeThoughtLevel,
}) {
  return CursorCatalogSnapshot(
    modelConfigId: "model-picker",
    models: const [
      CursorCatalogOption(value: "gpt-5.4", name: "GPT-5.4", description: null),
      CursorCatalogOption(value: "sonnet-4.6", name: "Sonnet 4.6", description: null),
    ],
    loadedModelId: loadedModelId,
    modeConfigId: "mode-picker",
    modes: const [
      CursorCatalogOption(value: "agent", name: "Agent", description: null),
      CursorCatalogOption(value: "plan", name: "Plan", description: null),
    ],
    loadedModeId: loadedModeId,
    thoughtLevel: includeThoughtLevel
        ? CursorThoughtLevelSnapshot(
            configId: "effort",
            variants: const ["medium", "low", "high"],
            defaultValue: "medium",
          )
        : null,
  );
}
