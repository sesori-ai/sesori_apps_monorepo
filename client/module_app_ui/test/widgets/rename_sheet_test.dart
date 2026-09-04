import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

Future<void> _pumpRenameSheet({
  required WidgetTester tester,
  required Future<bool> Function(String value) onRename,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, _) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () {
                unawaited(
                  showPregoBottomSheet<void>(
                    context: context,
                    title: "Rename",
                    builder: (_) => RenameSheet(
                      initialValue: "Original",
                      hintText: "Name",
                      saveLabel: "Save",
                      failureMessage: "Rename failed",
                      onRename: onRename,
                    ),
                  ),
                );
              },
              child: const Text("Open rename"),
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, "Open rename"));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("dismisses immediately and stays silent after a successful rename", (tester) async {
    final renameCompleter = Completer<bool>();
    String? submittedValue;
    await _pumpRenameSheet(
      tester: tester,
      onRename: (value) {
        submittedValue = value;
        return renameCompleter.future;
      },
    );

    await tester.enterText(find.byType(TextField), "  New name  ");
    await tester.tap(find.widgetWithText(FilledButton, "Save"));
    await tester.pumpAndSettle();

    expect(submittedValue, "New name");
    expect(renameCompleter.isCompleted, isFalse);
    expect(find.byType(RenameSheet), findsNothing);
    expect(find.byType(PregoPopupAlertsNotifications), findsNothing);

    renameCompleter.complete(true);
    await tester.pumpAndSettle();

    expect(find.byType(PregoPopupAlertsNotifications), findsNothing);
  });

  testWidgets("reports a failed rename after dismissing immediately", (tester) async {
    final renameCompleter = Completer<bool>();
    await _pumpRenameSheet(
      tester: tester,
      onRename: (_) => renameCompleter.future,
    );

    await tester.enterText(find.byType(TextField), "New name");
    await tester.tap(find.widgetWithText(FilledButton, "Save"));
    await tester.pumpAndSettle();

    expect(find.byType(RenameSheet), findsNothing);
    expect(find.text("Rename failed"), findsNothing);

    renameCompleter.complete(false);
    await tester.pumpAndSettle();

    expect(find.text("Rename failed"), findsOneWidget);
    expect(find.byType(PregoPopupAlertsNotifications), findsOneWidget);
  });
}
