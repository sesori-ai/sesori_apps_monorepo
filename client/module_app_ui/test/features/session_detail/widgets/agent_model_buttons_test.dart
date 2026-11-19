import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/model_effort_chip.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/model_level_strip.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show
        FastModeControl,
        FastModeToggleApply,
        FastModeToggleConfirmCacheReset,
        FastModeToggleDecision,
        FastModeToggleUnavailable;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// The agents a real project reports — a handful, each with a description long
/// enough to run past the row and ellipsize.
final _agents = [
  _agent(name: "build", description: "The default agent. Executes tools and edits files."),
  _agent(name: "plan", description: "Plan mode. Disallows all edit tools."),
  _agent(name: "aristotle-plan-review", description: "Reviews architecture-bearing development plans."),
  _agent(name: "aristotle-impl-review", description: "Reviews architecture-bearing production changes."),
];

AgentInfo _agent({required String name, required String description}) =>
    AgentInfo(name: name, description: description, model: null, mode: AgentMode.all);

Finder _menuItem(String label) => find.descendant(
  of: find.byType(PregoSingleChildScrollView),
  matching: find.widgetWithText(InkWell, label),
);

Widget _buildApp({
  required List<AgentInfo> agents,
  required void Function(String) onAgentSelected,
  required bool readOnly,
  required bool compact,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      // Bottom-aligned, like the composer the pickers actually live in.
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AgentModelButtons(
            readOnly: readOnly,
            surfaceStyle: PregoComposerSurfaceStyle.subtle,
            agents: agents,
            selectedAgent: "aristotle-impl-review",
            onAgentSelected: onAgentSelected,
            providers: const [],
            selectedAgentModel: null,
            onModelSelected: ({required providerID, required modelID, required variant}) => null,
            modelOrbits: null,
            fastModeControl: FastModeControl.hidden,
            decideFastModeToggle: () => null,
            onFastModeChanged: (_) {},
            compact: compact,
            trailing: const [],
          ),
        ],
      ),
    ),
  );
}

ProviderModel _providerModel({required String id, required String name, required List<String> variants}) =>
    ProviderModel(
      id: id,
      providerID: "example",
      name: name,
      // Strongest first, as every plugin catalog lists them.
      variants: variants,
      defaultVariant: null,
      family: null,
      fastMode: null,
      releaseDate: null,
    );

/// A catalog the orbits picker cannot draw: Oh My Pi's `auto` is off the
/// shared ladder, and one model has no effort at all.
final _effortProviders = [
  ProviderInfo(
    id: "example",
    name: "Example",
    models: {
      "alpha": _providerModel(
        id: "alpha",
        name: "Alpha",
        variants: const ["max", "xhigh", "high", "medium", "low", "minimal"],
      ),
      "beta": _providerModel(id: "beta", name: "Beta", variants: const []),
      "gamma": _providerModel(
        id: "gamma",
        name: "Gamma",
        variants: const ["xhigh", "high", "medium", "low", "minimal", "off", "auto"],
      ),
    },
    defaultModelID: "alpha",
  ),
];

typedef _Pick = ({String modelID, String? variant});

/// The composer over [_effortProviders], applying each pick as the cubits do:
/// the picked level, else the previous one when the model offers it, else the
/// model's first level.
class const _EffortHarness({
  required final AgentModel initial,
  required final List<_Pick> picks,
  required final bool compact,
}) extends StatefulWidget {
  @override
  State<_EffortHarness> createState() => _EffortHarnessState();
}

class _EffortHarnessState() extends State<_EffortHarness> {
  late AgentModel _selected = widget.initial;

  AgentModel? _select({required String providerID, required String modelID, required SessionVariant? variant}) {
    widget.picks.add((modelID: modelID, variant: variant?.id));
    final offered = _effortProviders.single.models[modelID]?.variants ?? const <String>[];
    final level = [variant?.id, _selected.variant].firstWhere(offered.contains, orElse: () => offered.firstOrNull);
    final applied = AgentModel(providerID: providerID, modelID: modelID, variant: level);
    setState(() => _selected = applied);
    return applied;
  }

  @override
  Widget build(BuildContext context) => AgentModelButtons(
    readOnly: false,
    surfaceStyle: PregoComposerSurfaceStyle.subtle,
    agents: const [],
    selectedAgent: null,
    onAgentSelected: (_) {},
    providers: _effortProviders,
    selectedAgentModel: _selected,
    onModelSelected: _select,
    modelOrbits: null,
    fastModeControl: FastModeControl.hidden,
    decideFastModeToggle: () => null,
    onFastModeChanged: (_) {},
    compact: widget.compact,
    trailing: const [],
  );
}

Future<List<_Pick>> _pumpEffort(
  WidgetTester tester, {
  required AgentModel initial,
  PregoInteractionMode mode = PregoInteractionMode.touch,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picks = <_Pick>[];
  await tester.pumpWidget(
    PregoInteractionScope(
      mode: mode,
      child: MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _EffortHarness(initial: initial, picks: picks, compact: mode == PregoInteractionMode.pointer),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
  );
  return picks;
}

Finder _strip() => find.byType(ModelLevelStrip);

/// The level segments left to right.
List<String> _stripLevels(WidgetTester tester) {
  final words = find.descendant(of: _strip(), matching: find.byType(Text)).evaluate().toList()
    ..sort(
      (a, b) => tester.getCenter(find.byWidget(a.widget)).dx.compareTo(tester.getCenter(find.byWidget(b.widget)).dx),
    );
  return [
    for (final word in words)
      if (word.widget case Text(:final data?)) data,
  ];
}

/// The list row showing [name].
Finder _row(String name) => find
    .ancestor(
      of: find.descendant(of: find.byType(ModelPicker), matching: find.text(name)),
      matching: find.byType(InkWell),
    )
    .first;

Widget _buildFastModeApp({
  required PregoDesignSystem designSystem,
  required FastModeControl control,
  required FastModeToggleDecision decision,
  required ValueChanged<bool> onFastModeChanged,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: [designSystem]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AgentModelButtons(
            readOnly: false,
            surfaceStyle: PregoComposerSurfaceStyle.subtle,
            agents: const [],
            selectedAgent: null,
            onAgentSelected: (_) {},
            providers: const [],
            selectedAgentModel: const AgentModel(providerID: "anthropic", modelID: "opus", variant: "high"),
            onModelSelected: ({required providerID, required modelID, required variant}) => null,
            modelOrbits: null,
            fastModeControl: control,
            decideFastModeToggle: () => decision,
            onFastModeChanged: onFastModeChanged,
            compact: false,
            trailing: const [],
          ),
        ],
      ),
    ),
  );
}

void main() {
  group("pill halos", () {
    for (final compact in [true, false]) {
      testWidgets("each pill has its own halo, so the row's gaps stay open (compact: $compact)", (tester) async {
        await tester.pumpWidget(
          _buildApp(agents: _agents, onAgentSelected: (_) {}, readOnly: false, compact: compact),
        );

        final halos = find.byType(PregoPageHalo);
        expect(halos, findsNWidgets(2));
        final haloWidths = [for (final halo in halos.evaluate()) tester.getSize(find.byWidget(halo.widget)).width];
        expect(
          haloWidths.reduce((a, b) => a + b),
          lessThan(tester.getSize(find.byType(AgentModelButtons)).width),
        );
      });
    }
  });

  group("Fast mode pill", () {
    Finder pill() => find.bySemanticsLabel("Fast mode");

    testWidgets("is hidden when the model has no fast mode", (tester) async {
      await tester.pumpWidget(
        _buildFastModeApp(
          designSystem: PregoDesignSystem.light,
          control: FastModeControl.hidden,
          decision: const FastModeToggleApply(fastMode: true),
          onFastModeChanged: (_) {},
        ),
      );

      expect(find.byIcon(TablerRegular.bolt), findsNothing);
      expect(find.byIcon(TablerRegular.bolt_off), findsNothing);
    });

    for (final (mode, side) in [(PregoInteractionMode.pointer, 28.0), (PregoInteractionMode.touch, 36.0)]) {
      testWidgets("is a $side point square under ${mode.name}, like the row's status chips", (tester) async {
        await tester.pumpWidget(
          PregoInteractionScope(
            mode: mode,
            child: _buildFastModeApp(
              designSystem: PregoDesignSystem.light,
              control: FastModeControl.off,
              decision: const FastModeToggleApply(fastMode: true),
              onFastModeChanged: (_) {},
            ),
          ),
        );

        expect(tester.getSize(pill()), Size.square(side));
      });
    }

    for (final (name, designSystem, expected) in [
      ("dark", PregoDesignSystem.dark, const Color(0xFFFEC84B)),
      ("light", PregoDesignSystem.light, const Color(0xFFF79009)),
    ]) {
      testWidgets("is tinted yellow while on in $name theme and applies a cold switch directly", (tester) async {
        final changes = <bool>[];
        await tester.pumpWidget(
          _buildFastModeApp(
            designSystem: designSystem,
            control: FastModeControl.on,
            decision: const FastModeToggleApply(fastMode: false),
            onFastModeChanged: changes.add,
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(TablerRegular.bolt));
        expect(icon.color, expected);
        expect(tester.getSemantics(pill()), isSemantics(isButton: true, isToggled: true));

        await tester.tap(pill());
        await tester.pumpAndSettle();
        expect(changes, [false]);
      });
    }

    testWidgets("is dimmed when unavailable and a tap explains why", (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _buildFastModeApp(
          designSystem: PregoDesignSystem.light,
          control: FastModeControl.unavailable,
          decision: const FastModeToggleUnavailable(reason: FastModeUnavailableReason.notOnPlan),
          onFastModeChanged: changes.add,
        ),
      );
      final context = tester.element(find.byType(AgentModelButtons));
      final loc = context.loc;

      expect(tester.widget<Icon>(find.byIcon(TablerRegular.bolt_off)).color, context.prego.colors.fgDisabled);

      await tester.tap(pill());
      await tester.pump();
      expect(find.text(loc.sessionDetailFastModeUnavailableTitle), findsOneWidget);
      expect(find.text(loc.sessionDetailFastModeUnavailableNotOnPlan), findsOneWidget);
      expect(changes, isEmpty);
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });

    testWidgets("asks before dropping a warm prompt cache", (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _buildFastModeApp(
          designSystem: PregoDesignSystem.light,
          control: FastModeControl.off,
          decision: const FastModeToggleConfirmCacheReset(fastMode: true),
          onFastModeChanged: changes.add,
        ),
      );
      final loc = tester.element(find.byType(AgentModelButtons)).loc;

      await tester.tap(pill());
      await tester.pumpAndSettle();
      expect(find.text(loc.sessionDetailFastModeConfirmTitle), findsOneWidget);
      expect(find.text(loc.sessionDetailFastModeConfirmEnableBody), findsOneWidget);
      expect(changes, isEmpty);
    });

    for (final (answer, respond, expected) in [
      ("confirmed", (WidgetTester tester) => tester.tap(find.byKey(const Key("fast_mode_confirm"))), [true]),
      ("cancelled", (WidgetTester tester) => tester.tap(find.byKey(const Key("fast_mode_cancel"))), <bool>[]),
      ("dismissed", (WidgetTester tester) => tester.tapAt(const Offset(10, 10)), <bool>[]),
    ]) {
      testWidgets("a cache-reset prompt that is $answer switches only on confirm", (tester) async {
        final changes = <bool>[];
        await tester.pumpWidget(
          _buildFastModeApp(
            designSystem: PregoDesignSystem.light,
            control: FastModeControl.off,
            decision: const FastModeToggleConfirmCacheReset(fastMode: true),
            onFastModeChanged: changes.add,
          ),
        );
        await tester.tap(pill());
        await tester.pumpAndSettle();

        await respond(tester);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key("fast_mode_confirm")), findsNothing);
        expect(changes, expected);
      });
    }
  });

  group("Model and effort", () {
    const alpha = AgentModel(providerID: "example", modelID: "alpha", variant: "high");

    testWidgets("a catalog without orbits shows one chip reading the model and its level", (tester) async {
      await _pumpEffort(tester, initial: alpha);

      expect(find.byType(ModelEffortChip), findsOneWidget);
      expect(find.text(" · High"), findsOneWidget);
      // No separate effort pill.
      expect(find.byType(PregoPickerButton), findsNothing);
      expect(find.byIcon(TablerRegular.gauge), findsNothing);
    });

    testWidgets("a model without effort reads only its name", (tester) async {
      await _pumpEffort(
        tester,
        initial: const AgentModel(providerID: "example", modelID: "beta", variant: null),
      );

      expect(find.byType(ModelEffortChip), findsOneWidget);
      expect(find.textContaining("·"), findsNothing);
    });

    testWidgets("the selected row shows its levels weakest to strongest", (tester) async {
      await _pumpEffort(tester, initial: alpha);
      await tester.tap(find.byType(ModelEffortChip));
      await tester.pumpAndSettle();

      expect(_strip(), findsOneWidget);
      expect(find.descendant(of: _row("Alpha"), matching: _strip()), findsOneWidget);
      expect(_stripLevels(tester), ["Minimal", "Low", "Medium", "High", "Xhigh", "Max"]);
      final selected = find.descendant(of: _strip(), matching: find.bySemanticsLabel("High effort"));
      expect(tester.getSemantics(selected), isSemantics(isSelected: true));
    });

    testWidgets("another row takes the strip with a size animation and the list stays open", (tester) async {
      final picks = await _pumpEffort(tester, initial: alpha);
      await tester.tap(find.byType(ModelEffortChip));
      await tester.pumpAndSettle();
      final alphaOpen = tester.getSize(_row("Alpha")).height;
      final gammaClosed = tester.getSize(_row("Gamma")).height;

      await tester.tap(_row("Gamma"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));

      // Halfway, the old row is shrinking while the new one grows.
      expect(tester.getSize(_row("Alpha")).height, inExclusiveRange(gammaClosed, alphaOpen));
      expect(tester.getSize(_row("Gamma")).height, inExclusiveRange(gammaClosed, alphaOpen));

      await tester.pumpAndSettle();
      expect(picks, [(modelID: "gamma", variant: null)]);
      expect(find.byType(ModelPicker), findsOneWidget);
      expect(find.descendant(of: _row("Alpha"), matching: _strip()), findsNothing);
      expect(find.descendant(of: _row("Gamma"), matching: _strip()), findsOneWidget);
      // Every level the harness reports, `auto` in its catalog place, and the
      // level the switch kept.
      expect(_stripLevels(tester), ["Auto", "Off", "Minimal", "Low", "Medium", "High", "Xhigh"]);
      expect(
        tester.getSemantics(find.descendant(of: _strip(), matching: find.bySemanticsLabel("High effort"))),
        isSemantics(isSelected: true),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("a model without effort says so in the strip's place", (tester) async {
      await _pumpEffort(tester, initial: alpha);
      await tester.tap(find.byType(ModelEffortChip));
      await tester.pumpAndSettle();
      final loc = tester.element(find.byType(ModelPicker)).loc;

      await tester.tap(_row("Beta"));
      await tester.pumpAndSettle();

      expect(_strip(), findsNothing);
      expect(find.descendant(of: _row("Beta"), matching: find.text(loc.modelPickerNoEffort)), findsOneWidget);
      expect(find.byType(ModelPicker), findsOneWidget);
    });

    for (final mode in PregoInteractionMode.values) {
      testWidgets("the list keeps its edges as the strip moves to a model without effort (${mode.name})", (
        tester,
      ) async {
        await _pumpEffort(tester, initial: alpha, mode: mode);
        await tester.tap(find.byType(mode == PregoInteractionMode.pointer ? PregoPickerButton : ModelEffortChip));
        await tester.pumpAndSettle();
        await tester.tap(_row("Gamma"));
        await tester.pumpAndSettle();
        final withLevels = tester.getRect(find.byType(ModelPicker));
        final gammaOpen = tester.getSize(_row("Gamma")).height;

        await tester.tap(_row("Beta"));
        await tester.pumpAndSettle();
        expect(_strip(), findsNothing);
        expect(tester.getRect(find.byType(ModelPicker)), withLevels);
        expect(tester.getSize(_row("Beta")).height, gammaOpen);
      });
    }

    testWidgets("a level commits the model and level together and closes the list", (tester) async {
      final picks = await _pumpEffort(tester, initial: alpha);
      await tester.tap(find.byType(ModelEffortChip));
      await tester.pumpAndSettle();
      await tester.tap(_row("Gamma"));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: _strip(), matching: find.text("Auto")));
      await tester.pumpAndSettle();

      expect(picks.last, (modelID: "gamma", variant: "auto"));
      expect(find.byType(ModelPicker), findsNothing);
      expect(find.text(" · Auto"), findsOneWidget);
    });

    testWidgets("a tap on the selected row keeps its choice and closes the list", (tester) async {
      final picks = await _pumpEffort(tester, initial: alpha);
      await tester.tap(find.byType(ModelEffortChip));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: _row("Alpha"), matching: find.text("Alpha")));
      await tester.pumpAndSettle();

      expect(picks, isEmpty);
      expect(find.byType(ModelPicker), findsNothing);
    });

    testWidgets("under a pointer, one pill reads the model and level and opens the same list", (tester) async {
      final picks = await _pumpEffort(tester, initial: alpha, mode: PregoInteractionMode.pointer);

      expect(find.byType(ModelEffortChip), findsNothing);
      expect(find.widgetWithText(PregoPickerButton, "Alpha · High"), findsOneWidget);
      await tester.tap(find.byType(PregoPickerButton));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: _strip(), matching: find.text("Low")));
      await tester.pumpAndSettle();
      expect(picks, [(modelID: "alpha", variant: "low")]);
      expect(find.widgetWithText(PregoPickerButton, "Alpha · Low"), findsOneWidget);
    });

    for (final mode in PregoInteractionMode.values) {
      testWidgets("read-only shows the model and level together under ${mode.name}", (tester) async {
        await tester.pumpWidget(
          PregoInteractionScope(
            mode: mode,
            child: MaterialApp(
              theme: ThemeData(extensions: [PregoDesignSystem.light]),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ReadOnlyAgentModelPills(
                  agents: const [],
                  agent: null,
                  providers: _effortProviders,
                  model: alpha,
                  compact: mode == PregoInteractionMode.pointer,
                ),
              ),
            ),
          ),
        );

        switch (mode) {
          case PregoInteractionMode.touch:
            expect(find.byType(ModelEffortChip), findsOneWidget);
            expect(find.text(" · High"), findsOneWidget);
          case PregoInteractionMode.pointer:
            expect(find.widgetWithText(PregoPickerButton, "Alpha · High"), findsOneWidget);
        }
        expect(find.byIcon(TablerRegular.gauge), findsNothing);
      });
    }
  });

  group("Agent picker", () {
    for (final mode in PregoInteractionMode.values) {
      testWidgets("leads with the robot under ${mode.name}, in the composer and read-only", (tester) async {
        IconData pillIcon() => tester
            .widget<PregoPickerButton>(
              find.ancestor(of: find.text("aristotle-impl-review"), matching: find.byType(PregoPickerButton)),
            )
            .leadingIcon;
        await tester.pumpWidget(
          PregoInteractionScope(
            mode: mode,
            child: _buildApp(agents: _agents, onAgentSelected: (_) {}, readOnly: false, compact: true),
          ),
        );
        expect(pillIcon(), TablerRegular.robot);

        await tester.pumpWidget(
          PregoInteractionScope(
            mode: mode,
            child: MaterialApp(
              theme: ThemeData(extensions: [PregoDesignSystem.light]),
              home: Scaffold(
                body: ReadOnlyAgentModelPills(
                  agents: _agents,
                  agent: "aristotle-impl-review",
                  providers: const [],
                  model: null,
                  compact: true,
                ),
              ),
            ),
          ),
        );
        expect(pillIcon(), TablerRegular.robot);
      });
    }

    testWidgets("appears only when there is more than one agent", (tester) async {
      final only = _agent(name: "aristotle-impl-review", description: "Reviews");
      for (final (agents, matcher) in [
        (const <AgentInfo>[], findsNothing),
        ([only], findsNothing),
        ([only, _agent(name: "other", description: "Other")], findsOneWidget),
      ]) {
        await tester.pumpWidget(_buildApp(agents: agents, onAgentSelected: (_) {}, readOnly: false, compact: false));
        expect(find.text("aristotle-impl-review"), matcher);
      }
    });

    testWidgets("shows every agent, with none clipped out of reach", (tester) async {
      await tester.pumpWidget(_buildApp(agents: _agents, onAgentSelected: (_) {}, readOnly: false, compact: false));

      await tester.tap(find.text("aristotle-impl-review"));
      await tester.pumpAndSettle();

      // Each agent is on screen, and the popup hides nothing below its fold —
      // the picker used to under-size itself around its subtitled rows, clipping
      // the last agent with no way to scroll to it.
      for (final agent in _agents) {
        expect(_menuItem(agent.name), findsOneWidget);
      }
      final popup = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(popup.maxScrollExtent, equals(0.0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("read-only keeps the agent pill in place without opening its picker", (tester) async {
      await tester.pumpWidget(_buildApp(agents: _agents, onAgentSelected: (_) {}, readOnly: false, compact: true));
      final pill = find.ancestor(of: find.text("aristotle-impl-review"), matching: find.byType(PregoPickerButton));
      final liveRect = tester.getRect(pill);

      await tester.pumpWidget(_buildApp(agents: _agents, onAgentSelected: (_) {}, readOnly: true, compact: true));
      expect(tester.getRect(pill), liveRect);
      await tester.tap(find.text("aristotle-impl-review"), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Keyboard users cannot reach it either.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(_menuItem("plan"), findsNothing);
    });

    testWidgets("selects the agent the tap landed on", (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _buildApp(agents: _agents, onAgentSelected: selected.add, readOnly: false, compact: false),
      );

      await tester.tap(find.text("aristotle-impl-review"));
      await tester.pumpAndSettle();

      // Aimed at the lower edge of a row, where the popup's tap arithmetic used
      // to have drifted far enough to select the agent below it.
      final row = _menuItem("plan");
      await tester.tapAt(tester.getRect(row).bottomCenter - const Offset(0, 4));
      await tester.pumpAndSettle();

      expect(selected, equals(["plan"]));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("scrolls when a project brings more agents than fit", (tester) async {
      final agents = [
        for (var i = 0; i < 14; i++) _agent(name: "agent-$i", description: "Agent number $i."),
      ];
      await tester.pumpWidget(_buildApp(agents: agents, onAgentSelected: (_) {}, readOnly: false, compact: false));

      await tester.tap(find.text("aristotle-impl-review"));
      await tester.pumpAndSettle();

      // Past the cap the rows scroll rather than being cut off.
      final popup = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(popup.maxScrollExtent, greaterThan(0.0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets("compact selectors size to their labels instead of sharing the strip", (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentModelButtons(
            readOnly: false,
            surfaceStyle: PregoComposerSurfaceStyle.subtle,
            agents: [
              _agent(name: "build", description: "Build"),
              _agent(name: "plan", description: "Plan"),
            ],
            selectedAgent: "build",
            onAgentSelected: (_) {},
            providers: const [],
            selectedAgentModel: const AgentModel(providerID: "example", modelID: "m", variant: "high"),
            onModelSelected: ({required providerID, required modelID, required variant}) => null,
            modelOrbits: null,
            fastModeControl: FastModeControl.hidden,
            decideFastModeToggle: () => null,
            onFastModeChanged: (_) {},
            compact: true,
            trailing: const [],
          ),
        ),
      ),
    );

    double width(String label) =>
        tester.getSize(find.byWidgetPredicate((widget) => widget is PregoPickerButton && widget.label == label)).width;
    // Each pill hugs its label, and none is stretched to the cap.
    expect(width("build"), lessThan(width("m · High")));
    expect(width("m · High"), lessThan(240));
  });

  for (final (width, chips, labels, compact) in [
    // The agent pill at the end of a touch row hugs its label.
    (320.0, 2, true, false),
    (390.0, 0, true, false),
    // A pointer composer squeezed by a narrow window.
    (240.0, 0, false, true),
  ]) {
    final shell = compact ? "pointer" : "touch";
    testWidgets("a $shell row at $width points with $chips status chips fits (labels: $labels)", (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget square(String label) => PregoComposerChip(
        icon: TablerRegular.clock,
        label: label,
        showLabel: false,
        isWarning: false,
        surfaceStyle: PregoComposerSurfaceStyle.subtle,
        onPressed: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              // The composer's own inset on a phone.
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AgentModelButtons(
                readOnly: false,
                surfaceStyle: PregoComposerSurfaceStyle.subtle,
                agents: [
                  _agent(name: "build", description: "Build"),
                  _agent(name: "plan", description: "Plan"),
                ],
                selectedAgent: "build",
                onAgentSelected: (_) {},
                providers: const [],
                selectedAgentModel: const AgentModel(providerID: "example", modelID: "sonnet", variant: "high"),
                onModelSelected: ({required providerID, required modelID, required variant}) => null,
                modelOrbits: null,
                fastModeControl: FastModeControl.off,
                decideFastModeToggle: () => null,
                onFastModeChanged: (_) {},
                compact: compact,
                trailing: [square("YOLO"), square("Auto-continue")].take(chips).toList(),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Agent and model pills under a pointer; the agent pill beside the
      // model and effort chip on touch.
      expect(find.byType(PregoPickerButton), findsNWidgets(compact ? 2 : 1));
      expect(find.byType(ModelEffortChip), compact ? findsNothing : findsOneWidget);
      // A crowded row keeps the pickers as glyphs; a roomy one keeps labels.
      expect(find.text("build"), labels ? findsOneWidget : findsNothing);
      expect(find.bySemanticsLabel("build"), findsOneWidget);
    });
  }
}
