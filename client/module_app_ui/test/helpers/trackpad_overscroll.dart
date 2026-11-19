import "package:flutter/gestures.dart" show PointerDeviceKind;
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";

/// Pushes a macOS trackpad past the end of the scroll view holding [target]
/// while a mouse cursor rests just above [target] (left of it in a horizontal
/// scroll view), and expects the overscroll stretch to grow steadily and settle
/// back at the edge.
///
/// Hovering a text field or button rebuilds it, so the content lays out again
/// as it slides under the resting cursor. A SingleChildScrollView snaps its
/// overscroll back to the edge on each such layout, which this catches as a
/// step that moves backwards.
Future<void> expectSteadyTrackpadOverscroll({required WidgetTester tester, required Finder target}) async {
  final position = Scrollable.of(tester.element(target)).position;
  expect(position.maxScrollExtent, greaterThan(0), reason: "the content must scroll for the overscroll to matter");
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
  final rect = tester.getRect(target);
  final vertical = position.axis == Axis.vertical;
  final cursor = vertical ? Offset(rect.center.dx, rect.top - 4) : Offset(rect.left - 4, rect.center.dy);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: cursor);
  addTearDown(mouse.removePointer);
  await tester.pump();

  final trackpad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
  await trackpad.panZoomStart(cursor);
  var previous = position.pixels;
  var hovered = false;
  for (var step = 1; step <= 40; step++) {
    await trackpad.panZoomUpdate(cursor, pan: vertical ? Offset(0, -12.0 * step) : Offset(-12.0 * step, 0));
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
