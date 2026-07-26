import "dart:async";

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
  required Stream<bool> isPendingStream,
  required VoidCallback onResolvedRemotely,
  bool Function()? isPendingNow,
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
                    isPendingStream: isPendingStream,
                    isPendingNow: isPendingNow ?? () => true,
                    onResolvedRemotely: onResolvedRemotely,
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
    final router = _createRouter(
      permission: _permission,
      capture: capture,
      isPendingStream: const Stream<bool>.empty(),
      onResolvedRemotely: () {},
    );
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
    final codeBlockDecoration = markdown.styleSheet!.codeblockDecoration! as BoxDecoration;
    expect(codeBlockDecoration.color, isNot(detailDecoration.color));
    expect((codeBlockDecoration.border! as Border).top.color, colors.borderSecondary);

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
      final router = _createRouter(
        permission: _permission,
        capture: capture,
        isPendingStream: const Stream<bool>.empty(),
        onResolvedRemotely: () {},
      );
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

  testWidgets("dismisses itself without replying when resolved on another device", (tester) async {
    final capture = _ReplyCapture();
    final isPending = StreamController<bool>();
    var remoteDismissals = 0;
    addTearDown(isPending.close);
    final router = _createRouter(
      permission: _permission,
      capture: capture,
      isPendingStream: isPending.stream,
      onResolvedRemotely: () => remoteDismissals++,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);
    expect(find.text("bash"), findsOneWidget);

    isPending.add(false);
    await tester.pumpAndSettle();

    expect(find.text("bash"), findsNothing);
    expect(capture.requestId, isNull);
    expect(capture.reply, isNull);
    expect(remoteDismissals, 1);
  });

  testWidgets("a local reply racing the resolved signal pops only the sheet", (tester) async {
    final capture = _ReplyCapture();
    final isPending = StreamController<bool>();
    var remoteDismissals = 0;
    addTearDown(isPending.close);
    final router = _createRouter(
      permission: _permission,
      capture: capture,
      isPendingStream: isPending.stream,
      onResolvedRemotely: () => remoteDismissals++,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);

    // Replying resolves the request optimistically: the `false` emission
    // arrives while the sheet is still mounted in its exit animation. The
    // listener must not pop a second time (that would remove the page).
    await tester.tap(find.text("Once"));
    isPending.add(false);
    await tester.pumpAndSettle();

    expect(capture.reply, PermissionReply.once);
    expect(find.text("bash"), findsNothing);
    expect(find.byKey(const Key("open-permission-modal")), findsOneWidget);
    expect(remoteDismissals, 0);
  });

  testWidgets("ignores replies tapped during the exit animation after a remote resolution", (tester) async {
    final capture = _ReplyCapture();
    final isPending = StreamController<bool>();
    addTearDown(isPending.close);
    final router = _createRouter(
      permission: _permission,
      capture: capture,
      isPendingStream: isPending.stream,
      onResolvedRemotely: () {},
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);

    isPending.add(false);
    // Mid exit animation: the buttons are still on screen and tappable, but
    // the request is already resolved — no reply may be sent.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text("Once"), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(capture.reply, isNull);
  });

  testWidgets("ignores the resolved signal while exiting from a barrier dismissal", (tester) async {
    final capture = _ReplyCapture();
    final isPending = StreamController<bool>();
    var remoteDismissals = 0;
    addTearDown(isPending.close);
    final router = _createRouter(
      permission: _permission,
      capture: capture,
      isPendingStream: isPending.stream,
      onResolvedRemotely: () => remoteDismissals++,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);

    // Barrier tap pops the route without going through the modal's dismiss
    // path; a resolution landing mid-exit-animation must not pop the page.
    await tester.tapAt(const Offset(200, 50));
    await tester.pump(const Duration(milliseconds: 50));
    isPending.add(false);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("open-permission-modal")), findsOneWidget);
    expect(remoteDismissals, 0);
  });

  testWidgets("keeps actions visible for a long request detail", (tester) async {
    final capture = _ReplyCapture();
    final permission = _permission.copyWith(
      description: List.filled(80, "echo a long permission request").join("\n"),
    );
    final router = _createRouter(
      permission: permission,
      capture: capture,
      isPendingStream: const Stream<bool>.empty(),
      onResolvedRemotely: () {},
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);

    expect(find.text("Reject"), findsOneWidget);
    expect(find.text("Once"), findsOneWidget);
    expect(find.text("Always Allow"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
