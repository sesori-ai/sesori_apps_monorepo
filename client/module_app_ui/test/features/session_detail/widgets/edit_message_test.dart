import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/edit_message_banner.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/edit_message_dialogs.dart";
import "package:sesori_app_ui/src/l10n/app_localizations.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

Future<void> _pump(WidgetTester tester, {required Widget Function(BuildContext context) builder}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => Scaffold(body: Center(child: builder(context))),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets("the banner cancels an edit until it is sent", (tester) async {
    var cancels = 0;
    var phase = SessionEditPhase.composing;
    late StateSetter setPhase;
    await _pump(
      tester,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          setPhase = setState;
          return EditMessageBanner(
            editing: SessionComposerEditing(messageId: "m1", phase: phase, leftOutCount: 2),
            onCancel: () => cancels++,
          );
        },
      ),
    );

    expect(find.text("Editing your message"), findsOneWidget);
    expect(find.textContaining("2 attachments"), findsOneWidget);
    await tester.tap(find.byKey(const Key("edit_message_cancel")));
    expect(cancels, 1);

    setPhase(() => phase = SessionEditPhase.sending);
    await tester.pump();
    await tester.tap(find.byKey(const Key("edit_message_cancel")), warnIfMissed: false);
    expect(cancels, 1, reason: "a sent edit cannot be called back");
  });

  testWidgets("the busy popup answers Stop and resend or Cancel", (tester) async {
    final answers = <bool?>[];
    await _pump(
      tester,
      builder: (context) => TextButton(
        onPressed: () async => answers.add(await showEditBusyDialog(context: context)),
        child: const Text("resend"),
      ),
    );

    await tester.tap(find.text("resend"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("edit_busy_stop_and_resend")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("resend"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("edit_busy_cancel")));
    await tester.pumpAndSettle();

    expect(answers, [true, false]);
  });
}
