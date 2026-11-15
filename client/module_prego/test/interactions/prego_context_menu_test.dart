import "package:flutter/gestures.dart" show PointerDeviceKind, kPrimaryButton, kSecondaryButton;
import "package:flutter/semantics.dart" show SemanticsAction;
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/menus/anchored_flat_panel.dart";
import "package:theme_prego/components/menus/anchored_spotlight_backdrop.dart";
import "package:theme_prego/module_prego.dart";

const _text = "alpha beta gamma delta";

void main() {
  late GlobalKey<PregoReadableSelectionAreaState> area;
  late List<String?> selectionAtPress;
  late int acted;
  late int tapped;
  late List<Object?> haptics;

  setUp(() {
    area = GlobalKey<PregoReadableSelectionAreaState>();
    selectionAtPress = [];
    acted = 0;
    tapped = 0;
    haptics = [];
  });

  Widget harness({required PregoInteractionMode mode}) => PregoInteractionScope(
    mode: mode,
    child: MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      home: Scaffold(
        body: Padding(
          // Away from the screen edge the menu keeps clear of, so a pointer
          // menu opens exactly at the click.
          padding: const EdgeInsets.only(top: 100),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: PregoContextMenu(
                menuWidth: 200,
                spotlight: PregoMenuSpotlight.listRow,
                onOpenChanged: null,
                entriesBuilder: () {
                  selectionAtPress.add(area.currentState?.selectedText);
                  return [
                    PregoMenuItem(
                      title: "Act",
                      subtitle: null,
                      isSelected: false,
                      shortcutLabel: null,
                      onTap: () => acted++,
                    ),
                  ];
                },
                builder: (context, menuOpen) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PregoReadableSelectionArea(key: area, child: const Text(_text)),
                    TextButton(onPressed: () => tapped++, child: Text(menuOpen ? "Open" : "Closed")),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void recordHaptics(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "HapticFeedback.vibrate") haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  final panel = find.byType(AnchoredFlatPanel);

  group("under a finger", () {
    testWidgets(
      "a long-press opens the spotlit menu with a light haptic instead of selecting a word",
      (tester) async {
        recordHaptics(tester);
        await tester.pumpWidget(harness(mode: PregoInteractionMode.touch));

        await tester.longPress(find.text(_text));
        await tester.pumpAndSettle();

        expect(panel, findsOneWidget);
        expect(find.byType(AnchoredSpotlightBackdrop), findsOneWidget);
        expect(find.text("Open"), findsOneWidget);
        expect(haptics, ["HapticFeedbackType.lightImpact"]);
        expect(area.currentState?.selectedText, isNull);

        await tester.tap(find.text("Act"));
        await tester.pumpAndSettle();
        expect(acted, 1);
        expect(panel, findsNothing);
        expect(find.text("Closed"), findsOneWidget);
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}),
    );

    testWidgets("a screen reader's long-press opens the menu, and the item keeps its own nodes", (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(harness(mode: PregoInteractionMode.touch));
      expect(find.semantics.byLabel(_text), findsOne);

      tester.semantics.longPress(find.semantics.byAction(SemanticsAction.longPress));
      await tester.pumpAndSettle();

      expect(panel, findsOneWidget);
      semantics.dispose();
    });

    testWidgets("a tap still reaches the item, and a drag opens nothing", (tester) async {
      await tester.pumpWidget(harness(mode: PregoInteractionMode.touch));

      await tester.tap(find.text("Closed"));
      await tester.pumpAndSettle();
      expect(tapped, 1);

      final drag = await tester.startGesture(tester.getCenter(find.text(_text)));
      await drag.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(seconds: 1));
      await drag.up();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    });

    testWidgets("selectAll through the area's key selects its text", (tester) async {
      await tester.pumpWidget(harness(mode: PregoInteractionMode.touch));
      // The text registers with the selection area after the first frame.
      await tester.pump();

      area.currentState?.selectAll();
      await tester.pumpAndSettle();

      expect(area.currentState?.selectedText, _text);
    });
  });

  group("under a pointer", () {
    testWidgets(
      "a secondary click opens the menu at the pointer and leaves the selection to copy",
      (tester) async {
        recordHaptics(tester);
        await tester.pumpWidget(harness(mode: PregoInteractionMode.pointer));
        final start = tester.getTopLeft(find.text(_text)) + const Offset(1, 5);
        final drag = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
        await tester.pump();
        await drag.moveTo(start + const Offset(60, 0));
        await drag.up();
        await tester.pumpAndSettle();
        final selected = area.currentState?.selectedText;
        expect(selected, isNotNull);

        final click = tester.getCenter(find.text(_text));
        await tester.tapAt(click, buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();

        expect(panel, findsOneWidget);
        expect(tester.getTopLeft(find.descendant(of: panel, matching: find.byType(Material)).first), click);
        expect(find.byType(AnchoredSpotlightBackdrop), findsNothing);
        // The press saw the drag's selection, not a word the right-click picked.
        expect(selectionAtPress, [selected]);
        // The selection area's own context menu stays shut.
        expect(find.text("Select all"), findsNothing);
        expect(haptics, isEmpty);
      },
      variant: const TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.windows}),
    );

    testWidgets("a secondary click on an item over another item opens only the top one's menu", (tester) async {
      Widget menu({required String title, required Widget child}) => PregoContextMenu(
        menuWidth: 200,
        spotlight: PregoMenuSpotlight.listRow,
        onOpenChanged: null,
        entriesBuilder: () => [
          PregoMenuItem(title: title, subtitle: null, isSelected: false, shortcutLabel: null, onTap: () {}),
        ],
        builder: (context, menuOpen) => child,
      );
      await tester.pumpWidget(
        PregoInteractionScope(
          mode: PregoInteractionMode.pointer,
          child: MaterialApp(
            theme: ThemeData(extensions: [PregoDesignSystem.light]),
            home: Scaffold(
              body: Center(
                child: menu(
                  title: "Under",
                  child: menu(title: "Over", child: const Text(_text)),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tapAt(tester.getCenter(find.text(_text)), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(find.text("Over"), findsOneWidget);
      expect(find.text("Under"), findsNothing);
    });

    testWidgets("a held mouse button selects rather than opening the menu", (tester) async {
      await tester.pumpWidget(harness(mode: PregoInteractionMode.pointer));

      final press = await tester.startGesture(
        tester.getCenter(find.text(_text)),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      await tester.pump(const Duration(seconds: 1));
      await press.up();
      await tester.pumpAndSettle();

      expect(panel, findsNothing);
    });
  });

  testWidgets("reports the close even when the item went while its menu was open", (tester) async {
    final changes = <bool>[];
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: shown,
            builder: (context, show, _) => show
                ? PregoContextMenu(
                    menuWidth: 200,
                    spotlight: PregoMenuSpotlight.listRow,
                    onOpenChanged: changes.add,
                    entriesBuilder: () => [
                      PregoMenuItem(title: "Act", subtitle: null, isSelected: false, shortcutLabel: null, onTap: () {}),
                    ],
                    builder: (context, menuOpen) => const Text(_text),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.longPress(find.text(_text));
    await tester.pumpAndSettle();
    shown.value = false;
    await tester.pump();
    await tester.tap(find.text("Act"));
    await tester.pumpAndSettle();

    expect(changes, [true, false]);
  });
}
