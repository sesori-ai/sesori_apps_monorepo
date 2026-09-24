import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show FastModeControl;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

ProviderModel _model({
  required String id,
  required String name,
  required String? family,
  required DateTime releaseDate,
}) {
  return ProviderModel(
    fastMode: null,
    id: id,
    providerID: "test-provider",
    name: name,
    variants: const [],
    defaultVariant: null,
    family: family,
    releaseDate: releaseDate,
  );
}

List<ProviderInfo> _providers() {
  return [
    ProviderInfo(
      id: "anthropic",
      name: "Anthropic",
      models: {
        "claude-new": _model(
          id: "claude-new",
          name: "Claude Sonnet (latest)",
          family: "claude",
          releaseDate: DateTime(2026),
        ),
        "claude-old": _model(
          id: "claude-old",
          name: "Claude Opus Classic",
          family: "claude",
          releaseDate: DateTime(2024),
        ),
      },
      defaultModelID: null,
    ),
    ProviderInfo(
      id: "zeta",
      name: "Zeta AI",
      models: {
        "z-1": _model(id: "z-1", name: "Zeta One", family: null, releaseDate: DateTime(2025)),
      },
      defaultModelID: null,
    ),
  ];
}

const _claudeNew = AgentModel(providerID: "anthropic", modelID: "claude-new", variant: null);

Widget _buildApp({
  required AgentModel selected,
  required PregoInteractionMode mode,
  required void Function({required String providerID, required String modelID}) onModelSelected,
}) {
  return PregoInteractionScope(
    mode: mode,
    child: MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        // Bottom-aligned, like the composer the picker lives in.
        body: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AgentModelButtons(
              surfaceStyle: PregoComposerSurfaceStyle.subtle,
              agents: const [],
              selectedAgent: null,
              onAgentSelected: (_) {},
              providers: _providers(),
              selectedAgentModel: selected,
              onModelSelected: onModelSelected,
              availableVariants: const [],
              onVariantSelected: (_) {},
              fastModeControl: FastModeControl.hidden,
              decideFastModeToggle: () => null,
              onFastModeChanged: (_) {},
              compact: mode == PregoInteractionMode.pointer,
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _openPicker({required WidgetTester tester}) async {
  await tester.tap(find.byType(PregoPickerButton));
  await tester.pumpAndSettle();
}

/// The option row painted with the keyboard and mouse highlight.
Finder _highlighted({required String label}) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).color == PregoDesignSystem.light.colors.bgBrandPrimary,
  ),
);

void main() {
  testWidgets("opens beside the model pill with each provider's representative models", (tester) async {
    await tester.pumpWidget(
      _buildApp(
        selected: _claudeNew,
        mode: PregoInteractionMode.touch,
        onModelSelected: ({required providerID, required modelID}) {},
      ),
    );
    await _openPicker(tester: tester);

    expect(find.byType(ModelPicker), findsOneWidget);
    expect(find.text("ANTHROPIC"), findsOneWidget);
    expect(find.text("ZETA AI"), findsOneWidget);
    expect(find.text("Zeta One"), findsOneWidget);
    // Only the family representative is visible by default; the "(latest)"
    // marker is stripped from the display name.
    expect(find.text("Claude Opus Classic"), findsNothing);
    expect(
      find.descendant(of: find.widgetWithText(InkWell, "Claude Sonnet"), matching: find.byIcon(TablerRegular.check)),
      findsOneWidget,
    );
    // The picker opens above the pill, clear of the composer.
    final panel = tester.getRect(find.byType(ModelPicker));
    expect(panel.bottom, lessThanOrEqualTo(tester.getRect(find.byType(PregoPickerButton)).top));
    expect(panel.height, lessThanOrEqualTo(PregoPickerPopover.maxHeight));
  });

  testWidgets("an open picker follows a selection made elsewhere and keeps its search", (tester) async {
    void onModelSelected({required String providerID, required String modelID}) {}
    await tester.pumpWidget(
      _buildApp(selected: _claudeNew, mode: PregoInteractionMode.touch, onModelSelected: onModelSelected),
    );
    await _openPicker(tester: tester);
    await tester.enterText(find.byType(TextField), "zeta");
    await tester.pump();

    await tester.pumpWidget(
      _buildApp(
        selected: const AgentModel(providerID: "zeta", modelID: "z-1", variant: null),
        mode: PregoInteractionMode.touch,
        onModelSelected: onModelSelected,
      ),
    );
    await tester.pump();

    expect(find.text("ANTHROPIC"), findsNothing);
    expect(
      find.descendant(of: find.widgetWithText(InkWell, "Zeta One"), matching: find.byIcon(TablerRegular.check)),
      findsOneWidget,
    );
  });

  testWidgets("search reveals non-default family members and filters providers", (tester) async {
    await tester.pumpWidget(
      _buildApp(
        selected: _claudeNew,
        mode: PregoInteractionMode.touch,
        onModelSelected: ({required providerID, required modelID}) {},
      ),
    );
    await _openPicker(tester: tester);

    await tester.enterText(find.byType(TextField), "Opus");
    await tester.pump();

    expect(find.text("Claude Opus Classic"), findsOneWidget);
    expect(find.text("Claude Sonnet"), findsNothing);
    expect(find.text("Zeta One"), findsNothing);
    expect(find.text("ZETA AI"), findsNothing);
  });

  testWidgets("tapping a model selects it and closes the picker", (tester) async {
    final selected = <(String, String)>[];
    await tester.pumpWidget(
      _buildApp(
        selected: _claudeNew,
        mode: PregoInteractionMode.touch,
        onModelSelected: ({required providerID, required modelID}) => selected.add((providerID, modelID)),
      ),
    );
    await _openPicker(tester: tester);

    await tester.tap(find.text("Zeta One"));
    await tester.pumpAndSettle();

    expect(selected, [("zeta", "z-1")]);
    expect(find.byType(ModelPicker), findsNothing);
  });

  testWidgets("under a pointer, the keyboard and mouse move one highlight and Enter picks it", (tester) async {
    final selected = <(String, String)>[];
    await tester.pumpWidget(
      _buildApp(
        selected: _claudeNew,
        mode: PregoInteractionMode.pointer,
        onModelSelected: ({required providerID, required modelID}) => selected.add((providerID, modelID)),
      ),
    );
    await _openPicker(tester: tester);

    // The search field has focus, so typing filters at once.
    expect(tester.state<EditableTextState>(find.byType(EditableText)).widget.focusNode.hasFocus, isTrue);
    expect(_highlighted(label: "Claude Sonnet"), findsOneWidget);

    // Down passes over the provider heading; the ends hold the highlight.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_highlighted(label: "Zeta One"), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_highlighted(label: "Zeta One"), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_highlighted(label: "Claude Sonnet"), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text("Zeta One")));
    await tester.pump();
    expect(_highlighted(label: "Zeta One"), findsOneWidget);
    expect(_highlighted(label: "Claude Sonnet"), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, [("zeta", "z-1")]);
    expect(find.byType(ModelPicker), findsNothing);
  });

  testWidgets("under a pointer, Esc closes the picker without a selection", (tester) async {
    final selected = <(String, String)>[];
    await tester.pumpWidget(
      _buildApp(
        selected: _claudeNew,
        mode: PregoInteractionMode.pointer,
        onModelSelected: ({required providerID, required modelID}) => selected.add((providerID, modelID)),
      ),
    );
    await _openPicker(tester: tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(ModelPicker), findsNothing);
    expect(selected, isEmpty);
  });

  testWidgets("under touch, nothing is highlighted and the keyboard stays down", (tester) async {
    await tester.pumpWidget(
      _buildApp(
        selected: _claudeNew,
        mode: PregoInteractionMode.touch,
        onModelSelected: ({required providerID, required modelID}) {},
      ),
    );
    await _openPicker(tester: tester);

    expect(tester.state<EditableTextState>(find.byType(EditableText)).widget.focusNode.hasFocus, isFalse);
    expect(_highlighted(label: "Claude Sonnet"), findsNothing);
  });
}
