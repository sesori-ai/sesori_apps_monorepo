import "package:flutter/gestures.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/core/widgets/desktop_window_drag_area.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

void main() {
  late _MockWindowHost windowHost;
  late int clicks;

  setUp(() {
    windowHost = _MockWindowHost();
    clicks = 0;
    when(windowHost.startDragging).thenAnswer((_) async {});
    when(windowHost.toggleZoom).thenAnswer((_) async {});
  });

  // A 40 pt region over a page whose toolbar button sits inside it.
  Widget region({required bool zoomOnDoubleClick}) => MaterialApp(
    home: DesktopWindowDragArea(
      windowHost: windowHost,
      height: 40,
      zoomOnDoubleClick: zoomOnDoubleClick,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 80,
          height: 40,
          child: TextButton(onPressed: () => clicks++, child: const Text("Back")),
        ),
      ),
    ),
  );

  Future<void> press({
    required WidgetTester tester,
    required Offset at,
    required Offset travel,
    int buttons = kPrimaryButton,
  }) async {
    final gesture = await tester.startGesture(at, kind: PointerDeviceKind.mouse, buttons: buttons);
    await gesture.moveBy(travel);
    await gesture.up();
    // Outlasts the timer a double-tap recognizer starts on every press it sees.
    await tester.pump(kDoubleTapMinTime);
  }

  testWidgets("a press that travels inside the region drags the window, and only that", (tester) async {
    await tester.pumpWidget(region(zoomOnDoubleClick: false));

    await press(tester: tester, at: const Offset(400, 20), travel: Offset.zero);
    await press(tester: tester, at: const Offset(400, 60), travel: const Offset(40, 0));
    await press(tester: tester, at: const Offset(400, 20), travel: const Offset(40, 0), buttons: kSecondaryButton);
    verifyNever(windowHost.startDragging);

    await press(tester: tester, at: const Offset(400, 20), travel: const Offset(40, 0));
    verify(windowHost.startDragging).called(1);
  });

  testWidgets("a button in the region keeps its click, even one that jiggles", (tester) async {
    await tester.pumpWidget(region(zoomOnDoubleClick: false));

    await press(tester: tester, at: const Offset(40, 20), travel: const Offset(6, 0));
    expect(clicks, 1);
    verifyNever(windowHost.startDragging);

    // Dragged away, the press is no click any more: it moves the window.
    await press(tester: tester, at: const Offset(40, 20), travel: const Offset(40, 0));
    expect(clicks, 1);
    verify(windowHost.startDragging).called(1);
  });

  testWidgets("a double click zooms only where the region asks for it", (tester) async {
    Future<void> doubleClick() async {
      await tester.tapAt(const Offset(400, 20), kind: PointerDeviceKind.mouse);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(const Offset(400, 20), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(region(zoomOnDoubleClick: false));
    await doubleClick();
    verifyNever(windowHost.toggleZoom);

    await tester.pumpWidget(region(zoomOnDoubleClick: true));
    await doubleClick();
    verify(windowHost.toggleZoom).called(1);
    verifyNever(windowHost.startDragging);
  });

  testWidgets("the app's band over the shell's strip still hands one press to the host once", (tester) async {
    await tester.pumpWidget(
      DesktopWindowDragArea(
        windowHost: windowHost,
        height: 54,
        zoomOnDoubleClick: false,
        child: region(zoomOnDoubleClick: true),
      ),
    );

    await press(tester: tester, at: const Offset(400, 20), travel: const Offset(40, 0));
    verify(windowHost.startDragging).called(1);

    // Below the strip only the band is left.
    await press(tester: tester, at: const Offset(400, 48), travel: const Offset(40, 0));
    verify(windowHost.startDragging).called(1);
  });

  testWidgets("a host failure is logged instead of breaking the gesture", (tester) async {
    when(windowHost.startDragging).thenAnswer((_) async => throw StateError("window is gone"));
    await tester.pumpWidget(region(zoomOnDoubleClick: false));

    await press(tester: tester, at: const Offset(400, 20), travel: const Offset(40, 0));

    verify(windowHost.startDragging).called(1);
    expect(tester.takeException(), isNull);
  });
}

class _MockWindowHost() extends Mock implements WindowHost;
