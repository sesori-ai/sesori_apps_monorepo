import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_mobile/core/widgets/copy_icon_button.dart";
import "package:sesori_mobile/features/session_detail/widgets/permission_modal.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

const _command = "dart run build_runner build --delete-conflicting-outputs";

const _permission = SesoriPermissionAsked(
  requestID: "permission-1",
  sessionID: "session-1",
  displaySessionId: null,
  tool: "bash",
  description: _command,
);

class _ReplyCapture {
  String? requestId;
  String? sessionId;
  PermissionReply? reply;

  void onReply({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) {
    this.requestId = requestId;
    this.sessionId = sessionId;
    this.reply = reply;
  }
}

GoRouter _createRouter({
  required SesoriPermissionAsked permission,
  required _ReplyCapture capture,
}) {
  return GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key("open-permission-modal"),
                onPressed: () {
                  PermissionModal.show(
                    context,
                    permission: permission,
                    onReply: capture.onReply,
                  );
                },
                child: const Text("Open permission modal"),
              ),
            ),
          );
        },
      ),
    ],
  );
}

Widget _buildApp({required GoRouter router}) {
  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

Future<void> _openPermissionModal(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key("open-permission-modal")));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("groups the tool and highlighted request detail in one card", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(permission: _permission, capture: capture);
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);

    expect(find.text("bash"), findsOneWidget);
    expect(find.text(_command), findsOneWidget);
    expect(find.byIcon(TablerRegular.terminal), findsOneWidget);

    final colors = PregoDesignSystem.light.colors;
    final card = tester.widget<Container>(find.byKey(const Key("permission-detail-card")));
    final cardDecoration = card.decoration! as BoxDecoration;
    expect(cardDecoration.color, colors.bgSurface1);
    expect((cardDecoration.border! as Border).top.color, colors.borderSecondary);

    final detail = tester.widget<Container>(find.byKey(const Key("permission-request-detail")));
    final detailDecoration = detail.decoration! as BoxDecoration;
    expect(detailDecoration.color, colors.bgQuaternary);

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, _command);
    expect(markdown.selectable, isTrue);

    final copyButton = tester.widget<CopyIconButton>(find.byType(CopyIconButton));
    expect(copyButton.text, _command);
  });

  for (final replyCase in const [
    (label: "Reject", reply: PermissionReply.reject),
    (label: "Once", reply: PermissionReply.once),
    (label: "Always Allow", reply: PermissionReply.always),
  ]) {
    testWidgets("forwards the ${replyCase.label.toLowerCase()} reply", (tester) async {
      final capture = _ReplyCapture();
      final router = _createRouter(permission: _permission, capture: capture);
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildApp(router: router));
      await _openPermissionModal(tester);
      await tester.tap(find.text(replyCase.label));
      await tester.pumpAndSettle();

      expect(capture.requestId, _permission.requestID);
      expect(capture.sessionId, _permission.sessionID);
      expect(capture.reply, replyCase.reply);
    });
  }

  testWidgets("keeps actions visible for a long request detail", (tester) async {
    final capture = _ReplyCapture();
    final permission = _permission.copyWith(
      description: List.filled(80, "echo a long permission request").join("\n"),
    );
    final router = _createRouter(permission: permission, capture: capture);
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);

    expect(find.text("Reject"), findsOneWidget);
    expect(find.text("Once"), findsOneWidget);
    expect(find.text("Always Allow"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
