import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

import "thread_state_motion_playbook.dart";

void main() {
  testWidgets("replays completion on the same row and can interrupt it", (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ThreadStateMotionPlaybook());

    final detail = find.byKey(const ValueKey("replay-detail"));
    final row = find.byKey(const ValueKey("replay-thread"));
    final initialState = tester.state(detail);

    await tester.tap(find.text("Finish"));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<SessionTile>(row).isActive, isFalse);
    expect(tester.widget<PregoAiLoader>(detail).animate, isFalse);
    expect(tester.state(detail), same(initialState));

    await tester.tap(find.text("Start working"));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<SessionTile>(row).isActive, isTrue);
    expect(tester.widget<PregoAiLoader>(detail).animate, isTrue);
    expect(tester.state(detail), same(initialState));
    expect(tester.takeException(), isNull);
  });
}
