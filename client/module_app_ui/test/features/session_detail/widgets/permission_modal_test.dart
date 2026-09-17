import "dart:async";

import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

const _command = "dart run build_runner build --delete-conflicting-outputs";

const _permission = SesoriPermissionAsked(
  requestID: "permission-1",
  sessionID: "child-session-1",
  displaySessionId: "root-session-1",
  tool: "bash",
  description: _command,
  allowAlways: true,
);

Future<bool> _ignoreExternalLink({required Uri url, required UrlLaunchMode mode}) async => true;

class _ReplyCapture() {
  String? requestId;
  String? sessionId;
  PermissionReply? reply;
  bool isPending = true;
  final pending = StreamController<bool>();

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
  ExternalLinkOpener openExternalLink = _ignoreExternalLink,
}) {
  addTearDown(capture.pending.close);
  final router = GoRouter(
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
                    isPendingStream: capture.pending.stream,
                    isPending: () => capture.isPending,
                    openExternalLink: openExternalLink,
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
  addTearDown(router.dispose);
  return router;
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
  for (final brightness in Brightness.values) {
    testWidgets("rich command keeps literal text and Markdown reason in $brightness", (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      const command = "printf '[literal] * [link](not-a-link)'";
      final router = _createRouter(
        permission: _permission.copyWith(
          details: const PermissionDetails.command(command: command),
          description: "Review **this command** before allowing it.",
        ),
        capture: _ReplyCapture(),
      );
      await tester.pumpWidget(_buildApp(router: router));
      await _openPermissionModal(tester);
      expect(find.text("Allow this command?"), findsOneWidget);
      expect(find.byWidgetPredicate((widget) => widget is SelectableText && widget.data == command), findsOneWidget);
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
        "Review **this command** before allowing it.",
      );
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets("file rows retain full cross-platform paths and known operations in $brightness", (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final router = _createRouter(
        permission: _permission.copyWith(
          details: const PermissionDetails.fileChanges(
            files: [
              PermissionFile(path: "/workspace/config.toml", operation: PermissionFileOperation.write),
              PermissionFile(path: r"C:\workspace\bridge.json", operation: PermissionFileOperation.create),
              PermissionFile(path: "/workspace/unknown.txt", operation: null),
            ],
          ),
        ),
        capture: _ReplyCapture(),
      );
      await tester.pumpWidget(_buildApp(router: router));
      await _openPermissionModal(tester);
      expect(find.text("Allow these file changes?"), findsOneWidget);
      expect(find.text("config.toml"), findsOneWidget);
      expect(find.text("/workspace/config.toml"), findsOneWidget);
      expect(find.text("bridge.json"), findsOneWidget);
      expect(find.text(r"C:\workspace\bridge.json"), findsOneWidget);
      expect(find.text("write"), findsOneWidget);
      expect(find.text("create"), findsOneWidget);
      expect(find.byType(PregoGroupedRow), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("network approval keeps target and command and hides unsupported Always", (tester) async {
    final router = _createRouter(
      permission: _permission.copyWith(
        allowAlways: false,
        details: const PermissionDetails.network(
          targets: ["https://example.com/full/path?q=1"],
          command: "curl https://example.com/full/path?q=1",
        ),
      ),
      capture: _ReplyCapture(),
    );
    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);
    expect(find.text("Allow this network access?"), findsOneWidget);
    expect(find.text("Connect to https://example.com/full/path?q=1"), findsOneWidget);
    expect(find.text("curl https://example.com/full/path?q=1"), findsOneWidget);
    expect(find.text("Always approve"), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("rich details stay reachable in a compact enlarged-text sheet", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final capture = _ReplyCapture();
    final router = _createRouter(
      permission: _permission.copyWith(
        details: PermissionDetails.fileChanges(
          files: [
            for (var i = 0; i < 8; i++)
              PermissionFile(
                path: "/very/long/full/workspace/path/file-$i.txt",
                operation: PermissionFileOperation.write,
              ),
          ],
        ),
      ),
      capture: capture,
    );
    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);
    final reject = find.widgetWithText(PregoButtonsSolid, "Don’t allow");
    await tester.scrollUntilVisible(reject, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(reject);
    await tester.pumpAndSettle();
    expect(capture.reply, PermissionReply.reject);
    expect(capture.sessionId, "child-session-1");
    expect(tester.takeException(), isNull);
  });

  testWidgets("uses the floating Prego sheet and preserves complete request details", (tester) async {
    final router = _createRouter(permission: _permission, capture: _ReplyCapture());
    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);

    expect(find.byType(PregoActionSheet), findsOneWidget);
    expect(find.byType(PregoTopNavigationSheets), findsNothing);
    expect(find.text("Allow this action?"), findsOneWidget);
    expect(find.text("bash"), findsOneWidget);
    expect(find.text(_command), findsOneWidget);
    expect(find.byIcon(TablerRegular.terminal), findsNothing);

    final colors = PregoDesignSystem.light.colors;
    final detail = tester.widget<Container>(find.byKey(const Key("permission-request-detail")));
    final decoration = detail.decoration! as BoxDecoration;
    expect(decoration.color, colors.bgSurface2);
    expect((decoration.border! as Border).top.color, colors.borderPrimary);
    expect(decoration.borderRadius, BorderRadius.circular(PregoRadius.xl));

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, _command);
    expect(markdown.selectable, isTrue);
    expect(markdown.styleSheet!.p!.fontSize, 12);
    final codeBlockDecoration = markdown.styleSheet!.codeblockDecoration! as BoxDecoration;
    expect(codeBlockDecoration.color, isNot(decoration.color));
    expect(find.byType(PregoCopyIconButton), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets("stacks full-width Allow, Always approve and Don't allow in Figma order", (tester) async {
    final router = _createRouter(permission: _permission, capture: _ReplyCapture());
    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);

    final buttons = tester.widgetList<PregoButtonsSolid>(find.byType(PregoButtonsSolid)).toList();
    expect(buttons.map((button) => button.label), ["Allow", "Always approve", "Don’t allow"]);
    expect(buttons.map((button) => button.hierarchy), [
      PregoButtonsSolidHierarchy.primaryAlt,
      PregoButtonsSolidHierarchy.secondary,
      PregoButtonsSolidHierarchy.tertiary,
    ]);
    expect(buttons.every((button) => button.fullWidth && button.size == PregoButtonsSolidSize.lg), isTrue);
    final rects = List.generate(3, (index) => tester.getRect(find.byType(PregoButtonsSolid).at(index)));
    expect(rects[1].top - rects[0].bottom, PregoSpacing.xl);
    expect(rects[2].top - rects[1].bottom, PregoSpacing.xl);
    expect(rects.map((rect) => rect.width).toSet(), hasLength(1));
    expect(rects.map((rect) => rect.height).toSet(), {44.0});
  });

  testWidgets("uses the presenting route's link opener inside the bottom sheet", (tester) async {
    Uri? openedUrl;
    UrlLaunchMode? openedMode;
    final router = _createRouter(
      permission: _permission.copyWith(description: "Read [the docs](https://example.com/docs)"),
      capture: _ReplyCapture(),
      openExternalLink: ({required url, required mode}) async {
        openedUrl = url;
        openedMode = mode;
        return true;
      },
    );
    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    markdown.onTapLink!("the docs", "https://example.com/docs", "the docs");
    await tester.pump();

    expect(openedUrl, Uri.parse("https://example.com/docs"));
    expect(openedMode, UrlLaunchMode.externalApp);
    expect(tester.takeException(), isNull);
  });

  for (final replyCase in const [
    (label: "Don’t allow", reply: PermissionReply.reject),
    (label: "Allow", reply: PermissionReply.once),
    (label: "Always approve", reply: PermissionReply.always),
  ]) {
    testWidgets("forwards ${replyCase.label} to the owning child without changing scope", (tester) async {
      final capture = _ReplyCapture();
      final router = _createRouter(permission: _permission, capture: capture);
      await tester.pumpWidget(_buildApp(router: router));
      await _openPermissionModal(tester);
      await tester.tap(find.text(replyCase.label));
      await tester.pumpAndSettle();

      expect(capture.requestId, _permission.requestID);
      expect(capture.sessionId, _permission.sessionID);
      expect(capture.reply, replyCase.reply);
      expect(find.byType(PermissionModal), findsNothing);
    });
  }

  testWidgets("keeps actions tappable while long Markdown scrolls", (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = _ReplyCapture();
    final router = _createRouter(
      permission: _permission.copyWith(description: "${List.filled(80, 'Request detail\n').join()}\nLast detail"),
      capture: capture,
    );
    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);

    final rejectBefore = tester.getRect(find.text("Don’t allow"));
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text("Don’t allow")), rejectBefore);
    expect(find.text("Don’t allow").hitTestable(), findsOneWidget);
    expect(find.text("Allow").hitTestable(), findsOneWidget);
    expect(find.text("Always approve").hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text("Don’t allow"));
    await tester.pumpAndSettle();
    expect(capture.reply, PermissionReply.reject);
  });

  testWidgets("hides always approve when the backend forbids it", (tester) async {
    final router = _createRouter(permission: _permission.copyWith(allowAlways: false), capture: _ReplyCapture());
    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);
    expect(find.text("Don’t allow"), findsOneWidget);
    expect(find.text("Allow"), findsOneWidget);
    expect(find.text("Always approve"), findsNothing);
  });

  for (final dismissBySwipe in [false, true]) {
    testWidgets("${dismissBySwipe ? 'swipe' : 'scrim'} dismissal does not answer the request", (tester) async {
      final capture = _ReplyCapture();
      final router = _createRouter(permission: _permission, capture: capture);
      await tester.pumpWidget(_buildApp(router: router));
      await _openPermissionModal(tester);
      if (dismissBySwipe) {
        await tester.drag(find.text("Allow this action?"), const Offset(0, 600));
      } else {
        await tester.tapAt(const Offset(10, 10));
      }
      await tester.pumpAndSettle();
      expect(find.byType(PermissionModal), findsNothing);
      expect(capture.reply, isNull);
    });
  }

  testWidgets("external settlement dismisses without replying again", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(permission: _permission, capture: capture);
    await tester.pumpWidget(_buildApp(router: router));
    await _openPermissionModal(tester);
    capture.isPending = false;
    capture.pending.add(false);
    await tester.pumpAndSettle();
    expect(find.byType(PermissionModal), findsNothing);
    expect(capture.reply, isNull);
  });
}
