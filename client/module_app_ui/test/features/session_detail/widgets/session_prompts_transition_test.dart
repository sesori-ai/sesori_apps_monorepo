import "dart:ui" show GestureSettings, PointerDeviceKind;

import "package:bloc_test/bloc_test.dart";
import "package:flutter/rendering.dart" show RenderBox, RenderRepaintBoundary;
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_prompts/session_prompts_view.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

class _MockImageClipboard() extends Mock implements ImageClipboard;

class _MockImageSaver() extends Mock implements ImageSaver;

class _MockImageSharer() extends Mock implements ImageSharer;

class _MockMessageImageRepository() extends Mock implements MessageImageRepository;

class _MockSessionRepository() extends Mock implements SessionRepository;

class _StubConnectionOverlayCubit() extends Cubit<ConnectionOverlayState> implements ConnectionOverlayCubit {
  this : super(const ConnectionOverlayState.hidden(connected: true));

  @override
  void reconnect() {}
}

class _StubDiffSummaryCubit() extends Cubit<DiffSummaryState> implements DiffSummaryCubit {
  this : super(const DiffSummaryState.unknown());

  @override
  String get sessionId => "session-1";

  @override
  Duration get refreshInterval => Duration.zero;
}

/// The session page without a composer: these tests cover the Prompts
/// screen's transition over the transcript, which the phone and desktop
/// shells share.
Widget _buildApp({required SessionDetailCubit cubit}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => BlocProvider<SessionDetailCubit>.value(
          value: cubit,
          child: SessionDetailPresentationScope(
            openHarnessSettings: () {},
            openBridgeSettings: () {},
            messageImageRepository: _MockMessageImageRepository.new,
            imageSaver: _MockImageSaver.new,
            imageClipboard: _MockImageClipboard.new,
            imageSharer: _MockImageSharer.new,
            sessionRepository: _MockSessionRepository.new,
            createPendingFormCubit: ({required requestId, required sessionId}) =>
                throw UnimplementedError("Forms are not under test"),
            createFilePreviewCubit: ({required reference}) =>
                throw UnimplementedError("File previews are not under test"),
            createExternalActionCubit: ({required requestId, required sessionId}) =>
                throw UnimplementedError("External actions are not under test"),
            canShareImages: true,
            openExternalLink: ({required url, required mode}) async => false,
            openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
            child: SessionDetailBody(
              projectId: "project-1",
              sessionId: "session-1",
              sessionTitle: "Session",
              readOnly: false,
              banner: null,
              onBack: context.pop,
              onShowDiffs: () {},
              pageChrome: null,
              menuEntriesBuilder: null,
              bottomControlsBuilder: null,
            ),
          ),
        ),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<ConnectionOverlayCubit>(create: (_) => _StubConnectionOverlayCubit()),
      BlocProvider<DiffSummaryCubit>(create: (_) => _StubDiffSummaryCubit()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

SessionDetailLoaded _loadedState({required List<MessageWithParts> messages}) {
  final provider = testProviderListResponse().items.first;
  return SessionDetailLoaded(
    interaction: const SessionInteractionState.available(displayName: "Claude Code", refreshError: null),
    messages: messages,
    launchHandoff: null,
    olderMessagesCursor: null,
    userMessagesBeforeOldest: null,
    promptIndex: null,
    streamingText: const {},
    sessionStatus: const SessionStatus.idle(),
    pendingQuestions: const [],
    pendingPermissions: const [],
    sessionTitle: "Session",
    session: testConstSession,
    pluginId: "opencode",
    supportsPromptAttachments: true,
    supportsFileUploads: false,
    offersSessionMcp: true,
    assistantAgentModel: null,
    children: const [],
    childStatuses: const {},
    isRootSession: true,
    isArchived: false,
    queuedMessages: const [],
    bridgePromptAttachments: const {},
    localSend: const LocalSendPhase.idle(),
    availableAgents: [testAgentInfo()],
    availableProviders: [provider],
    availableCommands: const [],
    selectedAgent: "coder",
    selectedAgentModel: AgentModel(providerID: provider.id, modelID: "model-1", variant: null),
    promptDefaults: null,
    fastMode: false,
    stagedCommand: null,
    isRefreshing: false,
    availableVariants: const [],
    cannotContinueMessage: null,
  );
}

void main() {
  late _MockSessionDetailCubit cubit;

  setUp(() {
    cubit = _MockSessionDetailCubit();
    when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.noticeStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.isRouteVisible).thenReturn(true);
    when(cubit.checkHarnessSetup).thenAnswer((_) async {});
  });

  group("the Prompts screen", () {
    MessageWithParts textMessage({required String id, required bool user, required String text}) => MessageWithParts(
      info: user
          ? Message.user(invocation: null, promptId: null, id: id, sessionID: "session-1", agent: null, time: null)
          : Message.assistant(id: id, sessionID: "session-1", agent: null, modelID: null, providerID: null, time: null),
      parts: [MessagePart.text(id: "$id-part", sessionID: "session-1", messageID: id, text: text)],
    );
    final turns = [
      for (var turn = 0; turn < 12; turn++) ...[
        textMessage(id: "u$turn", user: true, text: "Prompt $turn"),
        textMessage(
          id: "a$turn",
          user: false,
          text: List.generate(12, (index) => "Answer $turn.$index").join("\n\n"),
        ),
      ],
    ];
    final layer = find.byType(SessionPromptsView);

    ScrollPosition transcript(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key("session-detail-message-list-view")),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    Future<void> openPrompts(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key("session-detail-prompts")));
      await tester.pumpAndSettle();
      expect(layer, findsOneWidget);
    }

    setUp(() {
      final state = _loadedState(messages: turns);
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);
      when(() => cubit.reportPromptsOpened(entry: AnalyticsPromptsEntry.sessionBar)).thenReturn(null);
    });

    group("its transition", () {
      final listView = find.byKey(const Key("session-detail-message-list-view"));
      // The first box the transition paints, beneath the screen.
      Color dim(WidgetTester tester) => tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.ancestor(of: layer, matching: find.byType(AnimatedBuilder)).first,
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color;
      double opacity(WidgetTester tester) =>
          tester.widget<Opacity>(find.ancestor(of: layer, matching: find.byType(Opacity)).first).opacity;

      /// The transcript as the reader sees it: where its list sits, how far
      /// it is scrolled and the element that shows it.
      ({Rect rect, double pixels, Element element}) transcriptAsSeen(WidgetTester tester) =>
          (rect: tester.getRect(listView), pixels: transcript(tester).pixels, element: tester.element(listView));

      testWidgets("grows the screen in and back out over a dimmed transcript that never moves", (tester) async {
        await tester.pumpWidget(_buildApp(cubit: cubit));
        await tester.pumpAndSettle();
        final before = transcriptAsSeen(tester);
        final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;

        await tester.tap(find.byKey(const Key("session-detail-prompts")));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(opacity(tester), inExclusiveRange(0, 1));
        expect(tester.getRect(layer).width, inExclusiveRange(screen.width * 0.96, screen.width));
        final midwayDim = dim(tester).a;
        expect(transcriptAsSeen(tester), before);
        await tester.pumpAndSettle();
        expect(opacity(tester), 1);
        expect(dim(tester).a, greaterThan(midwayDim), reason: "the transcript dims as the screen comes in");
        expect(tester.getRect(layer), screen);

        await tester.tap(find.byTooltip("Close prompts"));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(opacity(tester), inExclusiveRange(0, 1));
        expect(tester.getRect(layer).width, inExclusiveRange(screen.width * 0.96, screen.width));
        expect(transcriptAsSeen(tester), before);
        await tester.pumpAndSettle();
        expect(layer, findsNothing);
        expect(transcriptAsSeen(tester), before);
      });

      for (final (setting, features) in const [
        ("reduced motion", FakeAccessibilityFeatures(reduceMotion: true)),
        ("animations removed", FakeAccessibilityFeatures(disableAnimations: true)),
      ]) {
        testWidgets("is a plain fade with $setting", (tester) async {
          tester.platformDispatcher.accessibilityFeaturesTestValue = features;
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;

          await tester.tap(find.byKey(const Key("session-detail-prompts")));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(opacity(tester), inExclusiveRange(0, 1));
          expect(tester.getRect(layer), screen);

          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip("Close prompts"));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(opacity(tester), inExclusiveRange(0, 1));
          expect(tester.getRect(layer), screen);
          await tester.pumpAndSettle();
          expect(layer, findsNothing);
        });
      }

      testWidgets("an edge swipe drags the screen under the finger and springs back when let go early", (tester) async {
        await tester.pumpWidget(_buildApp(cubit: cubit));
        await tester.pumpAndSettle();
        final before = transcriptAsSeen(tester);
        await openPrompts(tester);
        final width = tester.getSize(layer).width;

        var time = Duration.zero;
        final gesture = await tester.startGesture(const Offset(5, 300));
        Future<void> move(double dx) async {
          time += const Duration(milliseconds: 400);
          await gesture.moveBy(Offset(dx, 0), timeStamp: time);
          await tester.pump();
        }

        await move(30); // past the touch slop, which the screen does not jump by
        expect(tester.getTopLeft(layer).dx, 0);
        await move(100);
        expect(tester.getTopLeft(layer).dx, moreOrLessEquals(100), reason: "the screen follows the finger exactly");
        await move(-40);
        expect(tester.getTopLeft(layer).dx, moreOrLessEquals(60));
        expect(opacity(tester), 1);
        expect(transcriptAsSeen(tester), before);

        await gesture.up(timeStamp: time + const Duration(milliseconds: 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.getTopLeft(layer).dx, inExclusiveRange(1, 59), reason: "it springs back, not snaps");
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(layer).dx, 0);

        final far = await tester.startGesture(const Offset(5, 300));
        await far.moveBy(const Offset(30, 0), timeStamp: const Duration(seconds: 10));
        await far.moveBy(Offset(width * 0.6, 0), timeStamp: const Duration(seconds: 11));
        await tester.pump();
        await far.up(timeStamp: const Duration(seconds: 12));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.getTopLeft(layer).dx,
          inExclusiveRange(width * 0.6 + 1, width),
          reason: "past halfway it slides on out",
        );
        await tester.pumpAndSettle();
        expect(layer, findsNothing);
        expect(find.byType(SessionDetailBody), findsOneWidget);
        expect(transcriptAsSeen(tester), before);

        await openPrompts(tester);
        expect(tester.getRect(layer).width, width, reason: "the next opening grows in again");
        await tester.flingFrom(const Offset(5, 300), const Offset(120, 0), 1500);
        await tester.pumpAndSettle();
        expect(layer, findsNothing, reason: "a fast short swipe closes");
        expect(transcriptAsSeen(tester), before);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets("an edge swipe does not move the screen off iOS", (tester) async {
        await tester.pumpWidget(_buildApp(cubit: cubit));
        await tester.pumpAndSettle();
        await openPrompts(tester);

        await tester.flingFrom(const Offset(5, 300), const Offset(300, 0), 1500);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(layer), Offset.zero);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      /// Whether the layer is leaving: only a reversing transition ignores taps.
      bool leaving(WidgetTester tester) =>
          tester.widget<IgnorePointer>(find.ancestor(of: layer, matching: find.byType(IgnorePointer)).first).ignoring;

      /// Pumps frames until the transition starts to take the screen away.
      Future<void> pumpUntilLeaving(WidgetTester tester) async {
        for (var frame = 0; frame < 30 && !leaving(tester); frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      testWidgets("every way out but the edge swipe and a pinch out runs the opening backwards", (tester) async {
        await tester.pumpWidget(_buildApp(cubit: cubit));
        await tester.pumpAndSettle();
        final before = transcriptAsSeen(tester);
        final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
        final waysOut = <String, Future<void> Function()>{
          "the close button": () => tester.tap(find.byTooltip("Close prompts")),
          "Escape": () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
          "back": () => tester.binding.handlePopRoute(),
          // Last: the jump moves the transcript the others leave untouched.
          "a tapped prompt": () => tester.tap(find.text("Prompt 10").last),
        };

        for (final MapEntry(key: way, value: leave) in waysOut.entries) {
          await openPrompts(tester);
          await leave();
          await tester.pump();
          await pumpUntilLeaving(tester);
          await tester.pump(const Duration(milliseconds: 30));
          expect(layer, findsOneWidget, reason: "$way takes the screen away through the transition");
          expect(leaving(tester), isTrue, reason: "$way reverses the transition");
          expect(opacity(tester), inExclusiveRange(0, 1), reason: "$way fades the screen out");
          expect(
            tester.getRect(layer).width,
            inExclusiveRange(screen.width * 0.96, screen.width),
            reason: "$way shrinks the screen back",
          );
          await tester.pumpAndSettle();
          expect(layer, findsNothing, reason: way);
          expect(find.byType(SessionDetailBody), findsOneWidget, reason: "$way closed the screen, not the page");
          if (way != "a tapped prompt") expect(transcriptAsSeen(tester), before, reason: way);
        }
      }, variant: _pinchPlatforms);

      testWidgets("Android's predictive back closes it the same way once committed", (tester) async {
        await tester.pumpWidget(_buildApp(cubit: cubit));
        await tester.pumpAndSettle();
        final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
        await openPrompts(tester);
        Future<void> backGesture(String method, {required Map<String, Object?>? arguments}) =>
            tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              SystemChannels.backGesture.name,
              SystemChannels.backGesture.codec.encodeMethodCall(MethodCall(method, arguments)),
              (_) {},
            );

        await backGesture(
          "startBackGesture",
          arguments: {
            "touchOffset": [5.0, 300.0],
            "progress": 0.0,
            "swipeEdge": 0,
          },
        );
        await backGesture(
          "updateBackGestureProgress",
          arguments: {
            "touchOffset": [120.0, 300.0],
            "progress": 0.5,
            "swipeEdge": 0,
          },
        );
        await tester.pump();
        expect(tester.getRect(layer), screen, reason: "nothing follows a back the page will not take");
        expect(opacity(tester), 1);

        await backGesture("commitBackGesture", arguments: null);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(leaving(tester), isTrue);
        expect(opacity(tester), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(layer, findsNothing);
        expect(find.byType(SessionDetailBody), findsOneWidget);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      group("a pinch out", () {
        const slow = Duration(milliseconds: 200);
        Future<_TwoFingers> land(WidgetTester tester) =>
            _TwoFingers.land(tester: tester, center: tester.getCenter(layer), gap: 120);

        testWidgets("swells around the fingers, drifts with them, then dissolves past a third", (tester) async {
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          final before = transcriptAsSeen(tester);
          final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
          await openPrompts(tester);
          final landing = tester.getCenter(layer);

          // 40 px of a full 200 px spread: inside the first third.
          final fingers = await land(tester);
          await fingers.spread(scale: 160 / 120, stepTime: slow);
          expect(opacity(tester), 1, reason: "the screen stays readable for the first third");
          expect(tester.getRect(layer).width, greaterThan(screen.width), reason: "it swells with the fingers");
          expect(leaving(tester), isFalse, reason: "the fingers, not the clock, move it");
          await fingers.drift(by: const Offset(0, 60), stepTime: slow);
          final underFingers = tester.renderObject<RenderBox>(layer).localToGlobal(landing);
          expect(underFingers.dx, moreOrLessEquals(landing.dx, epsilon: 0.5));
          expect(underFingers.dy, moreOrLessEquals(landing.dy + 60, epsilon: 0.5), reason: "it drifts with them");

          await fingers.spread(scale: 280 / 120, stepTime: slow);
          final spread = opacity(tester);
          expect(spread, inExclusiveRange(0, 1), reason: "past a third it dissolves");
          expect(transcriptAsSeen(tester), before);

          await fingers.lift(after: slow);
          await tester.pump(const Duration(milliseconds: 20));
          expect(layer, findsOneWidget, reason: "it finishes leaving rather than vanishing");
          expect(opacity(tester), lessThan(spread));
          await tester.pumpAndSettle();
          expect(layer, findsNothing);
          expect(find.byType(SessionDetailBody), findsOneWidget);
          expect(transcriptAsSeen(tester), before);
        }, variant: _pinchPlatforms);

        testWidgets("let go short of 100 px eases back open", (tester) async {
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
          await openPrompts(tester);

          final fingers = await land(tester);
          await fingers.spread(scale: 210 / 120, stepTime: slow);
          await fingers.drift(by: const Offset(0, 40), stepTime: slow);
          final held = opacity(tester);
          expect(held, inExclusiveRange(0, 1));
          await fingers.lift(after: slow);
          await tester.pump(const Duration(milliseconds: 10));
          expect(opacity(tester), inExclusiveRange(held, 1), reason: "it eases back, not snaps");
          await tester.pumpAndSettle();
          expect(opacity(tester), 1);
          expect(tester.getRect(layer), screen, reason: "its drift went back with it");
        }, variant: _pinchPlatforms);

        testWidgets("spread all the way and brought back, it eases back open", (tester) async {
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
          await openPrompts(tester);

          final fingers = await land(tester);
          await fingers.spread(scale: 370 / 120, stepTime: slow);
          expect(layer, findsOneWidget, reason: "a full spread keeps the screen while the fingers are down");
          await fingers.spread(scale: 1, stepTime: slow);
          expect(opacity(tester), 1, reason: "and it follows them back");
          await fingers.lift(after: slow);
          await tester.pumpAndSettle();
          expect(opacity(tester), 1);
          expect(tester.getRect(layer), screen);
        }, variant: _pinchPlatforms);

        testWidgets("one sprung back leaves the screen closing toward where it opened", (tester) async {
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          Future<Rect> closingRect() async {
            await tester.tap(find.byTooltip("Close prompts"));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 60));
            final rect = tester.getRect(layer);
            await tester.pumpAndSettle();
            return rect;
          }

          await openPrompts(tester);
          final untouched = await closingRect();

          await openPrompts(tester);
          final fingers = await _TwoFingers.land(
            tester: tester,
            center: tester.getBottomLeft(layer) + const Offset(150, -150),
            gap: 120,
          );
          await fingers.spread(scale: 1.15, stepTime: slow);
          await fingers.lift(after: slow);
          await tester.pumpAndSettle();
          expect(await closingRect(), untouched, reason: "the fingers' point went with their pinch");
        }, variant: _pinchPlatforms);

        testWidgets("a second pinch while it springs back moves nothing", (tester) async {
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
          await openPrompts(tester);

          final first = await land(tester);
          await first.spread(scale: 1.15, stepTime: slow);
          await first.lift(after: slow);
          await tester.pump(const Duration(milliseconds: 20));
          final second = await land(tester);
          await second.spread(scale: 1.45, stepTime: slow);
          await second.lift(after: slow);
          await tester.pumpAndSettle();
          expect(layer, findsOneWidget, reason: "the spring-back finishes; the late pinch is not taken");
          expect(opacity(tester), 1);
          expect(tester.getRect(layer), screen);
        }, variant: _pinchPlatforms);

        testWidgets("closes for real fingers, which land apart in time and slide as they lift", (tester) async {
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          await openPrompts(tester);

          // A thumb and finger landing together on a row, the second 64 ms
          // after the first, both drifting up a little before they spread.
          const frame = Duration(milliseconds: 8);
          var time = Duration.zero;
          final row = tester.getCenter(find.text("Prompt 10").last);
          var thumb = row - const Offset(15, 0);
          var finger = row + const Offset(15, -3);
          final first = await tester.createGesture();
          final second = await tester.createGesture();
          Future<void> step({required Offset thumbBy, required Offset fingerBy}) async {
            time += frame;
            thumb += thumbBy;
            finger += fingerBy;
            await first.moveTo(thumb, timeStamp: time);
            await second.moveTo(finger, timeStamp: time);
            await tester.pump(frame);
          }

          await first.down(thumb, timeStamp: time);
          for (var move = 0; move < 8; move++) {
            time += frame;
            thumb -= const Offset(0, 0.4);
            await first.moveTo(thumb, timeStamp: time);
            await tester.pump(frame);
          }
          await second.down(finger, timeStamp: time);
          await tester.pump();
          for (var move = 0; move < 4; move++) {
            await step(thumbBy: const Offset(0, -1.5), fingerBy: const Offset(0, -1.5));
          }
          for (var move = 0; move < 12; move++) {
            await step(thumbBy: const Offset(-6, 2), fingerBy: const Offset(6, -2));
          }
          expect(opacity(tester), lessThan(0.5), reason: "the spread has taken the screen half away");

          // As they lift off the glass, the fingers slide a pixel back together.
          for (var move = 0; move < 3; move++) {
            await step(thumbBy: const Offset(1, 0), fingerBy: const Offset(-1, 0));
          }
          time += frame;
          await first.up(timeStamp: time);
          await tester.pump(frame);
          time += const Duration(milliseconds: 30);
          await second.up(timeStamp: time);
          await tester.pumpAndSettle();
          expect(layer, findsNothing, reason: "a wide spread closes the screen");
          expect(find.byType(SessionDetailBody), findsOneWidget);
        }, variant: _pinchPlatforms);

        testWidgets("a quick short spread eases back, and a quick wide one carries its speed out", (tester) async {
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          const quick = Duration(milliseconds: 10);
          await openPrompts(tester);

          final short = await land(tester);
          await short.spread(scale: 180 / 120, stepTime: quick);
          await short.lift(after: quick);
          await tester.pumpAndSettle();
          expect(opacity(tester), 1, reason: "short of 100 px it stays, however fast");

          Future<double> shownAfterRelease({required Duration stepTime}) async {
            final fingers = await land(tester);
            await fingers.spread(scale: 240 / 120, stepTime: stepTime);
            await fingers.lift(after: stepTime);
            await tester.pump(const Duration(milliseconds: 16));
            final shown = opacity(tester);
            await tester.pumpAndSettle();
            expect(layer, findsNothing);
            return shown;
          }

          final slowly = await shownAfterRelease(stepTime: slow);
          await openPrompts(tester);
          final quickly = await shownAfterRelease(stepTime: quick);
          expect(quickly, lessThan(slowly), reason: "the fingers' speed carries into the finish");
        }, variant: _pinchPlatforms);

        testWidgets("on a trackpad closes past halfway and springs back short of it", (tester) async {
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
          Future<void> trackpadPinch({required double scale}) async {
            final gesture = await tester.createGesture(kind: PointerDeviceKind.trackpad);
            await gesture.panZoomStart(tester.getCenter(layer));
            var time = Duration.zero;
            for (var step = 1; step <= 5; step++) {
              time += slow;
              await gesture.panZoomUpdate(tester.getCenter(layer), scale: 1 + (scale - 1) * step / 5, timeStamp: time);
              await tester.pump();
            }
            await gesture.panZoomEnd(timeStamp: time + slow);
            await tester.pump();
          }

          await openPrompts(tester);
          await trackpadPinch(scale: 1.15);
          await tester.pumpAndSettle();
          expect(opacity(tester), 1);
          expect(tester.getRect(layer), screen);

          await trackpadPinch(scale: 1.4);
          await tester.pump(const Duration(milliseconds: 20));
          expect(leaving(tester), isTrue);
          await tester.pumpAndSettle();
          expect(layer, findsNothing);
        }, variant: _pinchPlatforms);

        testWidgets("leaves scrolling, pinching in and the search field alone", (tester) async {
          // Short enough that the twelve prompts overflow and the list can scroll.
          tester.view.physicalSize = const Size(800, 400) * tester.view.devicePixelRatio;
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
          await openPrompts(tester);

          final list = find.descendant(
            of: layer,
            matching: find.byWidgetPredicate((widget) => widget is Scrollable && widget.axis == Axis.vertical),
          );
          final position = tester.state<ScrollableState>(list.first).position;
          final pixels = position.pixels;
          await tester.drag(list.first, Offset(0, pixels > position.minScrollExtent ? 300 : -300));
          await tester.pumpAndSettle();
          expect(position.pixels, isNot(pixels), reason: "one finger scrolls the list");
          expect(opacity(tester), 1);

          final fingers = await _TwoFingers.land(tester: tester, center: tester.getCenter(layer), gap: 240);
          await fingers.spread(scale: 0.5, stepTime: slow);
          await fingers.lift(after: slow);
          await tester.pumpAndSettle();
          expect(opacity(tester), 1, reason: "pinching in on the screen does nothing");
          expect(tester.getRect(layer), screen);

          final field = find.descendant(of: layer, matching: find.byType(EditableText));
          await tester.enterText(field, "Prompt");
          await tester.pumpAndSettle();
          final word = tester.getTopLeft(field) + Offset(8, tester.getSize(field).height / 2);
          await tester.tapAt(word);
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tapAt(word);
          await tester.pumpAndSettle();
          final selection = tester.widget<EditableText>(field).controller.selection;
          expect(selection, const TextSelection(baseOffset: 0, extentOffset: 6), reason: "a double tap selects");
          expect(layer, findsOneWidget);
        }, variant: _pinchPlatforms);

        testWidgets("takes the gesture from a list the first finger is already scrolling", (tester) async {
          // Short enough that the twelve prompts overflow and the list can scroll.
          tester.view.physicalSize = const Size(800, 400) * tester.view.devicePixelRatio;
          addTearDown(tester.view.resetPhysicalSize);
          // A phone's 8 px scroll slop, so 20 px is well into a scroll.
          tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
          addTearDown(tester.view.resetGestureSettings);
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          await openPrompts(tester);
          final list = find.descendant(
            of: layer,
            matching: find.byWidgetPredicate((widget) => widget is Scrollable && widget.axis == Axis.vertical),
          );
          final position = tester.state<ScrollableState>(list.first).position;
          final unscrolled = position.pixels;
          // A finger moving down the screen scrolls toward the list's start.
          final towardScroll = unscrolled > position.minScrollExtent ? 1.0 : -1.0;

          // Two fingers landing together reach the screen as one, which moves
          // past the scroll slop before the second is seen.
          var time = Duration.zero;
          var thumb = tester.getCenter(layer);
          final first = await tester.createGesture();
          final second = await tester.createGesture();
          await first.down(thumb, timeStamp: time);
          for (var move = 0; move < 4; move++) {
            time += const Duration(milliseconds: 16);
            thumb += Offset(0, 5 * towardScroll);
            await first.moveTo(thumb, timeStamp: time);
            await tester.pump();
          }
          final scrolled = position.pixels;
          expect(scrolled, isNot(unscrolled), reason: "the list took the first finger");

          var finger = thumb + const Offset(30, 0);
          await second.down(finger, timeStamp: time);
          await tester.pump();
          for (var move = 0; move < 12; move++) {
            time += const Duration(milliseconds: 16);
            thumb += Offset(-6, towardScroll);
            finger += Offset(6, towardScroll);
            await first.moveTo(thumb, timeStamp: time);
            await second.moveTo(finger, timeStamp: time);
            await tester.pump();
          }
          expect(position.pixels, scrolled, reason: "the list holds still from the second finger on");
          expect(opacity(tester), lessThan(1), reason: "the pinch out follows the fingers");

          time += const Duration(milliseconds: 16);
          await first.up(timeStamp: time);
          await second.up(timeStamp: time);
          await tester.pumpAndSettle();
          expect(layer, findsNothing, reason: "a spread of 144 px closes the screen");
          expect(find.byType(SessionDetailBody), findsOneWidget);
        }, variant: _pinchPlatforms);

        testWidgets("moves the screen without repainting it or the page beneath", (tester) async {
          await tester.pumpWidget(_buildApp(cubit: cubit));
          await tester.pumpAndSettle();
          await openPrompts(tester);
          RenderRepaintBoundary boundaryAbove(RenderObject node) => switch (node.parent) {
            final RenderRepaintBoundary boundary => boundary,
            final RenderObject parent => boundaryAbove(parent),
            null => throw StateError("No repaint boundary above $node"),
          };
          bool contains({required RenderObject ancestor, required RenderObject node}) => switch (node.parent) {
            final RenderObject parent => parent == ancestor || contains(ancestor: ancestor, node: parent),
            null => false,
          };
          final transcript = tester.renderObject(listView);
          final placement = tester.renderObject(find.ancestor(of: layer, matching: find.byType(Opacity)).first);
          final dim = tester.renderObject(
            find
                .descendant(
                  of: find.ancestor(of: layer, matching: find.byType(AnimatedBuilder)).first,
                  matching: find.byType(ColoredBox),
                )
                .first,
          );

          expect(
            contains(ancestor: boundaryAbove(dim), node: transcript),
            isFalse,
            reason: "the dim and the screen's placement repaint apart from the page",
          );
          expect(
            contains(ancestor: placement, node: boundaryAbove(tester.renderObject(layer))),
            isTrue,
            reason: "the screen's own content is only recomposited as it is placed",
          );
        });
      });
    });
  });
}

/// The platforms the transcript's pinch tests run on.
const _pinchPlatforms = TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android, TargetPlatform.macOS});

/// Two fingers across [center], [gap] px apart along the horizontal, moved
/// apart, together or along in even steps on a clock of their own, so slow
/// steps give the release no speed and quick ones do.
class _TwoFingers({
  required final WidgetTester tester,
  required final Offset center,
  required final double gap,
  required final TestGesture first,
  required final TestGesture second,
}) {
  late double _apart = gap;
  late Offset _center = center;
  Duration _time = Duration.zero;

  static Future<_TwoFingers> land({
    required WidgetTester tester,
    required Offset center,
    required double gap,
  }) async => _TwoFingers(
    tester: tester,
    center: center,
    gap: gap,
    first: await tester.startGesture(center - Offset(gap / 2, 0)),
    second: await tester.startGesture(center + Offset(gap / 2, 0)),
  );

  /// Moves them to [scale] times their landing gap in four steps, [stepTime]
  /// apart.
  Future<void> spread({required double scale, required Duration stepTime}) async {
    final from = _apart;
    for (var step = 1; step <= 4; step++) {
      _time += stepTime;
      _apart = from + (gap * scale - from) * step / 4;
      await _place();
    }
  }

  /// Moves them together [by] in four steps, [stepTime] apart, keeping their
  /// gap.
  Future<void> drift({required Offset by, required Duration stepTime}) async {
    final from = _center;
    for (var step = 1; step <= 4; step++) {
      _time += stepTime;
      _center = from + by * (step / 4);
      await _place();
    }
  }

  Future<void> _place() async {
    await first.moveTo(_center - Offset(_apart / 2, 0), timeStamp: _time);
    await second.moveTo(_center + Offset(_apart / 2, 0), timeStamp: _time);
    await tester.pump();
  }

  /// Lifts both, [after] the last move.
  Future<void> lift({required Duration after}) async {
    _time += after;
    await first.up(timeStamp: _time);
    await second.up(timeStamp: _time);
    await tester.pump();
  }
}
