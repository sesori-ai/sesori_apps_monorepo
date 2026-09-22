import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// The sub-agents pill reads by symbol: a spinner beside the running count,
/// the sub-agent glyph beside the total. A session that has used many
/// disposable sub-agents must not look as if all of them were running.
void main() {
  Session child(int index) => Session(
    branchName: null,
    id: "child-$index",
    pluginId: "opencode",
    projectID: "project-1",
    directory: "/project",
    parentID: "session-1",
    title: "Sub-agent $index",
    pullRequest: null,
    time: const SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
    promptDefaults: null,
    lastUserActivityAt: null,
  );

  Future<void> pump(WidgetTester tester, {required int total, required int running}) async {
    final children = [for (var i = 1; i <= total; i++) child(i)];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: BackgroundTasksBar(
              surfaceStyle: PregoComposerSurfaceStyle.subtle,
              projectId: "project-1",
              children: children,
              childStatuses: {
                for (final (index, session) in children.indexed)
                  session.id: index < running ? const SessionStatus.busy() : const SessionStatus.idle(),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("while sub-agents work, the running count leads and the total follows", (tester) async {
    await pump(tester, total: 28, running: 3);

    expect(find.byType(PregoActivityIndicator), findsOneWidget);
    expect(find.text("3"), findsOneWidget);
    expect(find.byIcon(TablerRegular.subtask), findsOneWidget);
    expect(find.text("28"), findsOneWidget);
    // Reading order: spinner, running count, glyph, total.
    expect(tester.getRect(find.text("3")).right, lessThan(tester.getRect(find.byIcon(TablerRegular.subtask)).left));
    expect(find.bySemanticsLabel("28 sub-agents, 3 working"), findsOneWidget);
  });

  testWidgets("idle, only the total shows behind the sub-agent glyph", (tester) async {
    await pump(tester, total: 28, running: 0);

    expect(find.byType(PregoActivityIndicator), findsNothing);
    expect(find.text("0"), findsNothing);
    expect(find.byIcon(TablerRegular.subtask), findsOneWidget);
    expect(find.text("28"), findsOneWidget);
  });

  testWidgets("tapping the pill opens the list above it, and a tap elsewhere closes it", (tester) async {
    await pump(tester, total: 3, running: 1);
    await tester.tap(find.byKey(const ValueKey("sub_agents_pill")));
    await tester.pumpAndSettle();

    expect(find.text("Sub-agents"), findsOneWidget);
    expect(find.text("Sub-agent 3"), findsOneWidget);
    expect(
      tester.getRect(find.text("Sub-agents")).bottom,
      lessThan(tester.getRect(find.byKey(const ValueKey("sub_agents_pill"))).top),
    );

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text("Sub-agents"), findsNothing);
  });
}
