import "package:flutter/gestures.dart" show PointerDeviceKind;
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";

/// Pushes a macOS trackpad past the end of the scroll view holding [field]
/// while a mouse cursor rests just above [field], and expects the overscroll
/// stretch to grow steadily and settle back at the edge.
///
/// Hovering a text field rebuilds it, so the content lays out again as the
/// field slides under the resting cursor. A SingleChildScrollView snaps its
/// overscroll back to the edge on each such layout, which this catches as a
/// step that moves backwards.
Future<void> expectSteadyTrackpadOverscroll({required WidgetTester tester, required Finder target}) async {
  final position = Scrollable.of(tester.element(target)).position;
  expect(position.maxScrollExtent, greaterThan(0), reason: "the content must scroll for the overscroll to matter");
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
  final rect = tester.getRect(target);
  final cursor = Offset(rect.center.dx, rect.top - 4);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: cursor);
  addTearDown(mouse.removePointer);
  await tester.pump();

  final trackpad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
  await trackpad.panZoomStart(cursor);
  var previous = position.pixels;
  var hovered = false;
  for (var step = 1; step <= 40; step++) {
    await trackpad.panZoomUpdate(cursor, pan: Offset(0, -12.0 * step));
    await tester.pump(const Duration(milliseconds: 16));
    expect(position.pixels, greaterThanOrEqualTo(previous), reason: "step $step snapped back");
    previous = position.pixels;
    hovered = hovered || tester.getRect(target).contains(cursor);
  }
  expect(position.pixels, greaterThan(position.maxScrollExtent));
  expect(hovered, isTrue, reason: "the target must slide under the cursor");
  await trackpad.panZoomEnd();
  await tester.pumpAndSettle();
  expect(position.pixels, position.maxScrollExtent);
}
