import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";
import "adaptive_session_router_test_harness.dart";

const _detailKey = ValueKey("session-detail-session-1");
const _detailLocation = "/projects/p1/sessions/session-1?title=Session+One&readOnly=false";

/// Android back as the platform sends it: a predictive edge swipe, or the
/// back button, which arrives as a plain route pop.
enum _Back() {
  gesture,
  button,
}

/// How the phone reaches a session from Projects.
enum _Entry() {
  activity,
  sessionList,
}

Future<void> _systemBack({required WidgetTester tester, required _Back back}) async {
  switch (back) {
    case _Back.button:
      await tester.binding.handlePopRoute();
    case _Back.gesture:
      Future<void> send({required String method, required Map<String, Object?>? arguments}) {
        return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          SystemChannels.backGesture.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
          (_) {},
        );
      }

      await send(
        method: "startBackGesture",
        arguments: {
          "touchOffset": [5.0, 300.0],
          "progress": 0.0,
          "swipeEdge": 0,
        },
      );
      await tester.pump();
      await send(
        method: "updateBackGestureProgress",
        arguments: {
          "touchOffset": [120.0, 300.0],
          "progress": 0.5,
          "swipeEdge": 0,
        },
      );
      await tester.pump();
      await send(method: "commitBackGesture", arguments: null);
  }
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  // The session screen animates indefinitely, so pumpAndSettle never returns.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _openModal({required WidgetTester tester, required Finder from, required String title}) async {
  // The sheet's future completes only when it closes; the test watches the tree.
  unawaited(showPregoModal<void>(context: tester.element(from), title: title, builder: (_) => Text("$title body")));
  await _settle(tester);
}

void main() {
  setUpAll(registerAllFallbackValues);

  for (final entry in _Entry.values) {
    for (final back in _Back.values) {
      testWidgets("Android back ($back) closes one sheet at a time over a session opened from $entry", (tester) async {
        final harness = AdaptiveSessionRouterTestHarness();
        await tester.binding.setSurfaceSize(const Size(390, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        try {
          await harness.setUp(
            initialLocation: "/projects",
            currentRouteDef: AppRouteDef.sessionDetail,
            sessionsByProject: {
              "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
            },
          );
          await tester.pumpWidget(harness.buildApp());
          await _settle(tester);

          switch (entry) {
            case _Entry.activity:
              // Projects' Activity pushes the session on its own, so it is the
              // only page on the session shell's navigator.
              unawaited(harness.router.push<void>(_detailLocation));
            case _Entry.sessionList:
              // Opening the project pushes its session list; a tap then goes to
              // the session, leaving the list under it on the shell's navigator.
              unawaited(harness.router.push<void>("/projects/p1/sessions"));
              await _settle(tester);
              harness.router.go(_detailLocation);
          }
          await _settle(tester);
          expect(find.byKey(_detailKey), findsOneWidget);

          await _openModal(tester: tester, from: find.byKey(_detailKey), title: "Steps");
          await _openModal(tester: tester, from: find.text("Steps body"), title: "Tool");
          expect(find.text("Tool body"), findsOneWidget);

          await _systemBack(tester: tester, back: back);
          expect(find.text("Tool body"), findsNothing);
          expect(find.text("Steps body"), findsOneWidget);
          expect(find.byKey(_detailKey), findsOneWidget);

          await _systemBack(tester: tester, back: back);
          expect(find.text("Steps body"), findsNothing);
          expect(find.byKey(_detailKey), findsOneWidget);

          await _systemBack(tester: tester, back: back);
          expect(find.byKey(_detailKey), findsNothing);
        } finally {
          await harness.tearDown();
        }
      });
    }
  }
}
