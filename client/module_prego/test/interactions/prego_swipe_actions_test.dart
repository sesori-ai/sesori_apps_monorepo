import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_prego/module_prego.dart';

/// The default test surface is 800 logical px wide, so the geometry the tests
/// assert against is:
/// - reveal width: 6 (start gap) + 40 (action) + 6 (gap) + 136 (the primary's
///   natural width — the harness child declares it, the component measures
///   it) + 16 (end inset) = 204, settle-open threshold 102;
/// - commit threshold: 0.6 * 800 = 480.
/// Drags lose ~18px to touch slop before the recognizer reports, so distances
/// keep a margin on their side of each threshold.
///
/// Rows built with a leading action declare a 120px one, so the leading
/// reveal is 16 (start inset) + 120 + 6 (end gap) = 142, settle-open
/// threshold 71. The commit threshold is the same 480 on either side — for
/// strips wider than that, it moves out to the reveal plus the 64px
/// clearance.
const double _surfaceWidth = 800;
const double _revealWidth = 204;
const double _primaryWidth = 136;
const double _leadingWidth = 120;

class _Counters {
  int contentTaps = 0;
  int actionTaps = 0;
  int primaryTaps = 0;
  int fullSwipes = 0;
  int leadingTaps = 0;
  int leadingFullSwipes = 0;
}

Widget _row({
  required String label,
  required _Counters counters,
  bool closeOnAction = false,
  double primaryWidth = _primaryWidth,
  double? leadingWidth,
  bool bottomHairline = false,
}) {
  return PregoSwipeActions(
    showBottomHairline: bottomHairline,
    leadingPrimaryActionBuilder: leadingWidth == null
        ? null
        : (context, close) => SizedBox(
            width: leadingWidth,
            child: TextButton(
              onPressed: () {
                counters.leadingTaps++;
                if (closeOnAction) close();
              },
              child: Text('Unread $label'),
            ),
          ),
    onLeadingFullSwipe: leadingWidth == null ? null : () => counters.leadingFullSwipes++,
    actionsBuilder: (context, close) => [
      GestureDetector(
        key: ValueKey('action-$label'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          counters.actionTaps++;
          if (closeOnAction) close();
        },
        child: const SizedBox(width: 40, height: 40, child: ColoredBox(color: Colors.blue)),
      ),
    ],
    // The SizedBox stands in for a real action's content-driven size — the
    // component measures it rather than being told.
    primaryActionBuilder: (context, close) => SizedBox(
      width: primaryWidth,
      child: TextButton(
        onPressed: () {
          counters.primaryTaps++;
          if (closeOnAction) close();
        },
        child: Text('Hide $label'),
      ),
    ),
    onFullSwipe: () => counters.fullSwipes++,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => counters.contentTaps++,
      child: SizedBox(
        height: 96,
        child: Center(child: Text('$label content')),
      ),
    ),
  );
}

Widget _harness({
  required List<Widget> rows,
  ScrollController? scrollController,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Directionality(
      textDirection: textDirection,
      child: Scaffold(
        body: ListView(
          controller: scrollController,
          children: [
            ...rows,
            for (var i = 0; i < 10; i++) const SizedBox(height: 96),
          ],
        ),
      ),
    ),
  );
}

/// Drags [label]'s row horizontally by [dx] and lets it settle.
Future<void> _swipe(WidgetTester tester, {required String label, required double dx}) async {
  await tester.drag(find.text('$label content'), Offset(dx, 0));
  await tester.pumpAndSettle();
}

/// The primary action's tappable rect for [label]'s row.
Rect _primaryRect(WidgetTester tester, String label) =>
    tester.getRect(find.widgetWithText(TextButton, 'Hide $label'));

/// The leading action's tappable rect for [label]'s row.
Rect _leadingRect(WidgetTester tester, String label) =>
    tester.getRect(find.widgetWithText(TextButton, 'Unread $label'));

/// Moves a held gesture in steps, the way a finger streams move events.
///
/// A single big `moveBy` only wins the gesture arena: with the default
/// [DragStartBehavior.start] the accepting event's whole delta is treated as
/// positioning and discarded, so the drag would register as zero movement.
/// [pumpEach] paces the stream — long pauses keep the release velocity under
/// the fling threshold.
Future<void> _moveInSteps(
  WidgetTester tester,
  TestGesture gesture, {
  required Offset total,
  int steps = 8,
  Duration pumpEach = const Duration(milliseconds: 16),
}) async {
  final step = Offset(total.dx / steps, total.dy / steps);
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    await tester.pump(pumpEach);
  }
}

void main() {
  testWidgets('rests closed: actions off-row, content tappable, none of the callbacks fired', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    // The strip is laid out past the row's end edge, clipped out of view.
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));

    await tester.tap(find.text('A content'));
    await tester.pumpAndSettle();
    expect(counters.contentTaps, 1);
    expect(counters.actionTaps, 0);
    expect(counters.primaryTaps, 0);
    expect(counters.fullSwipes, 0);
  });

  testWidgets('while closed the actions are excluded from semantics', (tester) async {
    final handle = tester.ensureSemantics();
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    expect(find.bySemanticsLabel('Hide A'), findsNothing);

    await _swipe(tester, label: 'A', dx: -150);

    expect(find.bySemanticsLabel('Hide A'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a short drag springs back closed', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    // ~62px after slop — under the 102px settle-open threshold.
    await _swipe(tester, label: 'A', dx: -80);

    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('a drag past half the reveal settles open with the actions in place and tappable', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    await _swipe(tester, label: 'A', dx: -150);

    // Open geometry: the primary sits its own width plus the end inset from
    // the row's end; the reveal width was measured, not declared.
    final rect = _primaryRect(tester, 'A');
    expect(rect.left, moreOrLessEquals(_surfaceWidth - 16 - _primaryWidth, epsilon: 1));
    expect(rect.width, moreOrLessEquals(_primaryWidth, epsilon: 1));

    await tester.tap(find.text('Hide A'));
    await tester.pumpAndSettle();
    expect(counters.primaryTaps, 1);

    final actionTarget = tester.getCenter(find.byKey(const ValueKey('action-A')));
    expect(actionTarget.dx, moreOrLessEquals(_surfaceWidth - _revealWidth + 6 + 20, epsilon: 1));
    await tester.tap(find.byKey(const ValueKey('action-A')));
    await tester.pumpAndSettle();
    expect(counters.actionTaps, 1);
    expect(counters.fullSwipes, 0);
  });

  testWidgets("the reveal geometry follows the primary action's natural width", (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters, primaryWidth: 100)]),
    );

    // Nothing boxes the primary at rest — the strip lays it out at whatever
    // width its content asks for.
    expect(_primaryRect(tester, 'A').width, moreOrLessEquals(100, epsilon: 1));

    await _swipe(tester, label: 'A', dx: -150);

    // Reveal: 6 + 40 + 6 + 100 + 16 = 168 — narrower than the default
    // harness's 204, because the measured geometry tracked the primary.
    final rect = _primaryRect(tester, 'A');
    expect(rect.left, moreOrLessEquals(_surfaceWidth - 16 - 100, epsilon: 1));
    expect(rect.width, moreOrLessEquals(100, epsilon: 1));
    final actionTarget = tester.getCenter(find.byKey(const ValueKey('action-A')));
    expect(actionTarget.dx, moreOrLessEquals(_surfaceWidth - 168 + 6 + 20, epsilon: 1));
  });

  testWidgets('an action can close the row through the builder callback', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters, closeOnAction: true)]));

    await _swipe(tester, label: 'A', dx: -150);
    await tester.tap(find.text('Hide A'));
    await tester.pumpAndSettle();

    expect(counters.primaryTaps, 1);
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('tapping the open row closes it without activating the content, which works again after', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    await _swipe(tester, label: 'A', dx: -150);
    // The tap intentionally lands on the close-catcher covering the content.
    await tester.tap(find.text('A content'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(counters.contentTaps, 0);
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));

    await tester.tap(find.text('A content'));
    await tester.pumpAndSettle();
    expect(counters.contentTaps, 1);
  });

  testWidgets('a tap anywhere outside the open row closes it', (tester) async {
    final counters = _Counters();
    final other = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters), _row(label: 'B', counters: other)]),
    );

    await _swipe(tester, label: 'A', dx: -150);
    await tester.tap(find.text('B content'));
    await tester.pumpAndSettle();

    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('opening a second row closes the first', (tester) async {
    final a = _Counters();
    final b = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: a), _row(label: 'B', counters: b)]));

    await _swipe(tester, label: 'A', dx: -150);
    await _swipe(tester, label: 'B', dx: -150);

    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
    expect(_primaryRect(tester, 'B').left, lessThan(_surfaceWidth));
  });

  testWidgets('scrolling the enclosing list closes the open row', (tester) async {
    final counters = _Counters();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters)], scrollController: scrollController),
    );

    await _swipe(tester, label: 'A', dx: -150);
    expect(_primaryRect(tester, 'A').left, lessThan(_surfaceWidth));

    // Programmatic, so the close is attributable to the scroll itself rather
    // than to the pointer-down of a scroll gesture.
    scrollController.jumpTo(40);
    await tester.pumpAndSettle();

    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('a full swipe past the commit threshold fires onFullSwipe once and closes', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    // ~502px after slop — past the 480px commit threshold.
    await _swipe(tester, label: 'A', dx: -520);

    expect(counters.fullSwipes, 1);
    expect(counters.primaryTaps, 0);
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('the primary action stretches during the overdrag, trailing edge pinned to the row end', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    // 8 steps of -70; the first step is spent winning the arena, leaving
    // ~490px of extent — past the 480px commit threshold.
    final gesture = await tester.startGesture(tester.getCenter(find.text('A content')));
    await _moveInSteps(tester, gesture, total: const Offset(-560, 0));

    final rect = _primaryRect(tester, 'A');
    expect(rect.right, moreOrLessEquals(_surfaceWidth - 16, epsilon: 1));
    expect(rect.width, greaterThan(_primaryWidth + 200));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(counters.fullSwipes, 1);
  });

  testWidgets('a strip wider than the commit fraction keeps a reachable open state', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters, primaryWidth: 500)]));

    // Reveal: 6 + 40 + 6 + 500 + 16 = 568 — past the 480px fractional
    // threshold, as happens with long labels, large text scales or narrow
    // rows. A release beyond that fraction but short of the reveal must
    // settle open, not commit…
    final gesture = await tester.startGesture(tester.getCenter(find.text('A content')));
    await _moveInSteps(
      tester,
      gesture,
      total: const Offset(-560, 0),
      pumpEach: const Duration(milliseconds: 100),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(counters.fullSwipes, 0);
    expect(_primaryRect(tester, 'A').left, moreOrLessEquals(_surfaceWidth - 16 - 500, epsilon: 1));

    // …and the commit is still reachable once the drag clears the reveal by
    // the stretch clearance. The content has slid off-row, so the re-grab
    // starts on the row's body.
    final commitGesture = await tester.startGesture(const Offset(100, 48));
    await _moveInSteps(
      tester,
      commitGesture,
      total: const Offset(-300, 0),
      pumpEach: const Duration(milliseconds: 100),
    );
    await commitGesture.up();
    await tester.pumpAndSettle();

    expect(counters.fullSwipes, 1);
  });

  testWidgets('a strip whose reveal crowds the row still opens, and still commits at the full-width drag', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters, primaryWidth: 700)]));

    // Reveal: 6 + 40 + 6 + 700 + 16 = 768, so reveal plus the 64px clearance
    // is 832 — beyond the 800px row, which is as far as the drag can reach.
    // A drag short of the full width must still settle open, not commit…
    final gesture = await tester.startGesture(tester.getCenter(find.text('A content')));
    await _moveInSteps(
      tester,
      gesture,
      total: const Offset(-880, 0),
      pumpEach: const Duration(milliseconds: 100),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(counters.fullSwipes, 0);
    expect(_primaryRect(tester, 'A').left, moreOrLessEquals(_surfaceWidth - 16 - 700, epsilon: 1));

    // …and the commit threshold caps at the row width: dragging to the full
    // width arms and fires. The content has slid off-row, so the re-grab
    // starts on the sliver of row the open strip spares.
    final commitGesture = await tester.startGesture(const Offset(16, 48));
    await _moveInSteps(
      tester,
      commitGesture,
      total: const Offset(-300, 0),
      pumpEach: const Duration(milliseconds: 100),
    );
    await commitGesture.up();
    await tester.pumpAndSettle();

    expect(counters.fullSwipes, 1);
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
  });

  testWidgets('re-grabbing the row while a committed swipe settles shut does not fire the commit again', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    // A full swipe deep past the 480px threshold: the commit fires on release
    // and the row starts settling shut from a still-past-threshold extent.
    final gesture = await tester.startGesture(tester.getCenter(find.text('A content')));
    await _moveInSteps(
      tester,
      gesture,
      total: const Offset(-880, 0),
      pumpEach: const Duration(milliseconds: 100),
    );
    await gesture.up();
    expect(counters.fullSwipes, 1);

    // One frame into the settle the extent is still past the threshold.
    // Grabbing the row there (the accepting move's delta is discarded, so the
    // grab itself adds no movement) and releasing must not fire again.
    await tester.pump(const Duration(milliseconds: 16));
    final regrab = await tester.startGesture(const Offset(100, 48));
    await tester.pump(const Duration(milliseconds: 8));
    await regrab.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await regrab.up();
    await tester.pumpAndSettle();

    expect(counters.fullSwipes, 1);
  });

  testWidgets('dragging past the threshold and back before releasing does not commit', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    final gesture = await tester.startGesture(tester.getCenter(find.text('A content')));
    await _moveInSteps(tester, gesture, total: const Offset(-560, 0));
    // Slow enough on the way back that the release is not a closing fling —
    // a fast fling back is its own cancel path.
    await _moveInSteps(
      tester,
      gesture,
      total: const Offset(300, 0),
      steps: 6,
      pumpEach: const Duration(milliseconds: 100),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(counters.fullSwipes, 0);
    // ~190px extent at release — past half the reveal, so it settles open.
    expect(_primaryRect(tester, 'A').left, lessThan(_surfaceWidth));
  });

  testWidgets('reveals with a start-edge drag under RTL', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters)], textDirection: TextDirection.rtl),
    );

    // In RTL the actions live past the left edge and a rightward drag reveals.
    expect(_primaryRect(tester, 'A').right, lessThanOrEqualTo(0));

    await _swipe(tester, label: 'A', dx: 150);

    final rect = _primaryRect(tester, 'A');
    expect(rect.left, moreOrLessEquals(16, epsilon: 1));

    await tester.tap(find.text('Hide A'));
    await tester.pumpAndSettle();
    expect(counters.primaryTaps, 1);
  });

  testWidgets('an end-ward drag on a row with no leading action stays closed', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    final before = tester.getTopLeft(find.text('A content'));
    await _swipe(tester, label: 'A', dx: 150);

    expect(tester.getTopLeft(find.text('A content')), before);
    // No catcher was raised either — the content still activates directly.
    await tester.tap(find.text('A content'));
    await tester.pumpAndSettle();
    expect(counters.contentTaps, 1);
  });

  testWidgets('rests with the leading action off-row; a drag past half its reveal settles it open', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters, leadingWidth: _leadingWidth)]),
    );

    // The leading strip is laid out past the row's start edge, clipped out of
    // view.
    expect(_leadingRect(tester, 'A').right, lessThanOrEqualTo(0));

    // ~102px after slop — past the 71px settle-open threshold.
    await _swipe(tester, label: 'A', dx: 120);

    // Open geometry: the action sits at the start inset, at its natural
    // width; the reveal width was measured, not declared.
    final rect = _leadingRect(tester, 'A');
    expect(rect.left, moreOrLessEquals(16, epsilon: 1));
    expect(rect.width, moreOrLessEquals(_leadingWidth, epsilon: 1));

    // The trailing side rides along closed.
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));

    await tester.tap(find.text('Unread A'));
    await tester.pumpAndSettle();
    expect(counters.leadingTaps, 1);
    expect(counters.leadingFullSwipes, 0);
  });

  testWidgets('tapping the row open on its leading action closes it without activating the content', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters, leadingWidth: _leadingWidth)]),
    );

    await _swipe(tester, label: 'A', dx: 120);
    // The tap intentionally lands on the close-catcher covering the content.
    await tester.tap(find.text('A content'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(counters.contentTaps, 0);
    expect(_leadingRect(tester, 'A').right, lessThanOrEqualTo(0));
  });

  testWidgets('a full end-ward swipe commits the leading action once and closes', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters, leadingWidth: _leadingWidth)]),
    );

    // ~502px after slop — past the 480px commit threshold.
    await _swipe(tester, label: 'A', dx: 520);

    expect(counters.leadingFullSwipes, 1);
    expect(counters.leadingTaps, 0);
    expect(counters.fullSwipes, 0);
    expect(_leadingRect(tester, 'A').right, lessThanOrEqualTo(0));
  });

  testWidgets('the leading action stretches during the overdrag, leading edge pinned to the row start', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters, leadingWidth: _leadingWidth)]),
    );

    // 8 steps of 70; the first step is spent winning the arena, leaving
    // ~490px of extent — past the 480px commit threshold.
    final gesture = await tester.startGesture(tester.getCenter(find.text('A content')));
    await _moveInSteps(tester, gesture, total: const Offset(560, 0));

    final rect = _leadingRect(tester, 'A');
    expect(rect.left, moreOrLessEquals(16, epsilon: 1));
    expect(rect.width, greaterThan(_leadingWidth + 200));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(counters.leadingFullSwipes, 1);
  });

  testWidgets('one drag can carry an open trailing row across to its leading side', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters, leadingWidth: _leadingWidth)]),
    );

    await _swipe(tester, label: 'A', dx: -150);
    expect(_primaryRect(tester, 'A').left, lessThan(_surfaceWidth));

    // From the +204 trailing reveal, ~402px of rightward extent after the
    // arena's first step crosses zero to about -198 — short of the commit
    // threshold, past half the leading reveal. Slow steps keep the release
    // under the fling velocity.
    final gesture = await tester.startGesture(tester.getCenter(find.text('A content')));
    await _moveInSteps(
      tester,
      gesture,
      total: const Offset(460, 0),
      pumpEach: const Duration(milliseconds: 100),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
    expect(_leadingRect(tester, 'A').left, moreOrLessEquals(16, epsilon: 1));
    expect(counters.fullSwipes, 0);
    expect(counters.leadingFullSwipes, 0);
  });

  testWidgets('a closing fling that overshoots past zero settles closed instead of opening the other side', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters, leadingWidth: _leadingWidth)]),
    );

    await _swipe(tester, label: 'A', dx: -150);
    expect(_primaryRect(tester, 'A').left, lessThan(_surfaceWidth));

    // From the +204 trailing reveal, a hard rightward fling: the first step is
    // spent winning the arena, the remaining +210 land a few pixels past
    // closed. The release must settle at zero — not read the overshoot as an
    // opening fling for the leading side. Explicit timestamps, because a
    // default moveBy stamps every event at zero and the release would carry
    // no velocity at all.
    final gesture = await tester.startGesture(tester.getCenter(find.text('A content')));
    await gesture.moveBy(const Offset(70, 0), timeStamp: const Duration(milliseconds: 8));
    await gesture.moveBy(const Offset(70, 0), timeStamp: const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(70, 0), timeStamp: const Duration(milliseconds: 24));
    await gesture.moveBy(const Offset(70, 0), timeStamp: const Duration(milliseconds: 32));
    await gesture.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(_leadingRect(tester, 'A').right, lessThanOrEqualTo(0));
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));
    expect(counters.fullSwipes, 0);
    expect(counters.leadingFullSwipes, 0);
  });

  testWidgets('a flick whose whole delta is spent winning the arena still opens the flicked side', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters, leadingWidth: _leadingWidth)]),
    );

    // Every event lands before or at arena acceptance, so the accepted drag
    // carries zero extent — only velocity (explicit timestamps; a default
    // moveBy stamps events at zero and would zero that too). It must still
    // open the flicked side, as the same flick did when the extent survived.
    final flick = await tester.startGesture(tester.getCenter(find.text('A content')));
    await flick.moveBy(const Offset(-6, 0), timeStamp: const Duration(milliseconds: 8));
    await flick.moveBy(const Offset(-6, 0), timeStamp: const Duration(milliseconds: 16));
    await flick.moveBy(const Offset(-288, 0), timeStamp: const Duration(milliseconds: 24));
    await flick.up(timeStamp: const Duration(milliseconds: 32));
    await tester.pumpAndSettle();

    expect(_primaryRect(tester, 'A').left, moreOrLessEquals(_surfaceWidth - 16 - _primaryWidth, epsilon: 1));

    // Close again, via the catcher covering the content.
    await tester.tap(find.text('A content'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_primaryRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));

    // The mirrored flick opens the leading side.
    final endFlick = await tester.startGesture(tester.getCenter(find.text('A content')));
    await endFlick.moveBy(const Offset(6, 0), timeStamp: const Duration(milliseconds: 8));
    await endFlick.moveBy(const Offset(6, 0), timeStamp: const Duration(milliseconds: 16));
    await endFlick.moveBy(const Offset(288, 0), timeStamp: const Duration(milliseconds: 24));
    await endFlick.up(timeStamp: const Duration(milliseconds: 32));
    await tester.pumpAndSettle();

    expect(_leadingRect(tester, 'A').left, moreOrLessEquals(16, epsilon: 1));
  });

  testWidgets('reveals the leading action with an end-edge drag under RTL', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(
        rows: [_row(label: 'A', counters: counters, leadingWidth: _leadingWidth)],
        textDirection: TextDirection.rtl,
      ),
    );

    // In RTL the leading action lives past the right edge and a leftward drag
    // reveals it.
    expect(_leadingRect(tester, 'A').left, greaterThanOrEqualTo(_surfaceWidth));

    await _swipe(tester, label: 'A', dx: -120);

    final rect = _leadingRect(tester, 'A');
    expect(rect.right, moreOrLessEquals(_surfaceWidth - 16, epsilon: 1));

    await tester.tap(find.text('Unread A'));
    await tester.pumpAndSettle();
    expect(counters.leadingTaps, 1);
  });

  testWidgets('the leading action joins semantics only while its side is open', (tester) async {
    final handle = tester.ensureSemantics();
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters, leadingWidth: _leadingWidth)]),
    );

    expect(find.bySemanticsLabel('Unread A'), findsNothing);

    await _swipe(tester, label: 'A', dx: 120);

    expect(find.bySemanticsLabel('Unread A'), findsOneWidget);
    // The other side's actions stay excluded while this one is open.
    expect(find.bySemanticsLabel('Hide A'), findsNothing);
    handle.dispose();
  });

  testWidgets("a closed side's action pills are excluded from focus traversal", (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(
      _harness(rows: [_row(label: 'A', counters: counters, leadingWidth: _leadingWidth)]),
    );

    FocusNode nodeOf(String label) => Focus.of(tester.element(find.text(label)));

    // At rest both strips are clipped off-row; their pills must not be
    // reachable tab stops.
    expect(nodeOf('Hide A').canRequestFocus, isFalse);
    expect(nodeOf('Unread A').canRequestFocus, isFalse);

    await _swipe(tester, label: 'A', dx: -150);

    // The open side's actions join traversal; the other side stays out.
    expect(nodeOf('Hide A').canRequestFocus, isTrue);
    expect(nodeOf('Unread A').canRequestFocus, isFalse);
  });

  testWidgets('the stationary bottom hairline is opt-in', (tester) async {
    final counters = _Counters();
    bool hairline(Widget widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        ((widget.decoration as BoxDecoration).border as Border?)?.bottom ==
            const BorderSide(color: PregoColorsLight.borderTertiary, width: 0);

    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));
    expect(
      find.descendant(of: find.byType(PregoSwipeActions), matching: find.byWidgetPredicate(hairline)),
      findsNothing,
    );

    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters, bottomHairline: true)]));
    expect(
      find.descendant(of: find.byType(PregoSwipeActions), matching: find.byWidgetPredicate(hairline)),
      findsOneWidget,
    );
  });

  testWidgets('a close settle keeps rendering the strip captured when the close began', (tester) async {
    Widget rowWith({required String primaryLabel}) {
      return _harness(rows: [
        PregoSwipeActions(
          actionsBuilder: (context, close) => const [SizedBox(width: 40, height: 40)],
          primaryActionBuilder: (context, close) => SizedBox(
            width: _primaryWidth,
            child: TextButton(onPressed: close, child: Text(primaryLabel)),
          ),
          onFullSwipe: () {},
          child: const SizedBox(height: 96, child: Center(child: Text('A content'))),
        ),
      ]);
    }

    await tester.pumpWidget(rowWith(primaryLabel: 'Mark unread'));
    await _swipe(tester, label: 'A', dx: -150);
    expect(find.text('Mark unread'), findsOneWidget);

    // The pill closes the row, and — the way a real read toggle does — the
    // consumer rebuilds with the opposite label while the row is still
    // settling shut. The still-visible pill must keep its captured label
    // instead of morphing mid-settle.
    await tester.tap(find.text('Mark unread'));
    await tester.pump();
    await tester.pumpWidget(rowWith(primaryLabel: 'Mark read'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Mark unread'), findsOneWidget);
    expect(find.text('Mark read'), findsNothing);

    await tester.pumpAndSettle();

    // Landed closed: the fresh builder output applies.
    expect(find.text('Mark unread'), findsNothing);
    expect(find.text('Mark read'), findsOneWidget);
  });

  testWidgets('the close callback is safe to call after the row is unmounted', (tester) async {
    late VoidCallback close;
    await tester.pumpWidget(
      _harness(rows: [
        PregoSwipeActions(
          actionsBuilder: (context, c) {
            close = c;
            return const [SizedBox(width: 40, height: 40)];
          },
          primaryActionBuilder: (context, _) => const SizedBox(width: _primaryWidth),
          onFullSwipe: () {},
          child: const SizedBox(height: 96),
        ),
      ]),
    );

    // A host may hold [close] across an await (a confirmation dialog, an undo
    // snackbar) while the row is removed underneath it.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(close, returnsNormally);
  });

  testWidgets('disposing mid-settle does not throw', (tester) async {
    final counters = _Counters();
    await tester.pumpWidget(_harness(rows: [_row(label: 'A', counters: counters)]));

    await tester.drag(find.text('A content'), const Offset(-150, 0));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
