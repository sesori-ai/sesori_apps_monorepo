import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/widgets/connection_banner.dart";
import "package:sesori_mobile/features/session_list/session_list_scaffold.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// A [StubConnectionOverlayCubit] whose state can be driven mid-test and that
/// counts `reconnect()` calls (the connection-lost banner's Retry action).
class _MutableConnectionOverlayCubit extends StubConnectionOverlayCubit {
  _MutableConnectionOverlayCubit({super.initialState});

  int reconnectCount = 0;

  void setOverlayState(ConnectionOverlayState next) => emit(next);

  @override
  void reconnect() => reconnectCount++;
}

class _MockSessionListCubit extends MockCubit<SessionListState> implements SessionListCubit {}

Widget _app({required ConnectionOverlayCubit cubit, required Widget home}) {
  return BlocProvider<ConnectionOverlayCubit>.value(
    value: cubit,
    child: MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  group("ConnectionBanner.maybeFor", () {
    Future<Widget?> resolveFor(WidgetTester tester, ConnectionOverlayState state) async {
      final cubit = StubConnectionOverlayCubit(initialState: state);
      addTearDown(cubit.close);
      Widget? resolved;
      await tester.pumpWidget(
        _app(
          cubit: cubit,
          home: Builder(
            builder: (context) {
              resolved = ConnectionBanner.maybeFor(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return resolved;
    }

    testWidgets("returns a banner for bridgeOffline and connectionLost, nothing otherwise", (tester) async {
      expect(
        await resolveFor(tester, const ConnectionOverlayState.bridgeOffline()),
        isA<ConnectionBanner>(),
      );
      expect(
        await resolveFor(tester, const ConnectionOverlayState.connectionLost()),
        isA<ConnectionBanner>(),
      );
      expect(await resolveFor(tester, const ConnectionOverlayState.hidden()), isNull);
      expect(await resolveFor(tester, const ConnectionOverlayState.reconnecting()), isNull);
    });
  });

  testWidgets("the connection-lost banner shows an error alert with a Reconnect action that retries", (tester) async {
    final cubit = _MutableConnectionOverlayCubit(
      initialState: const ConnectionOverlayState.connectionLost(),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      _app(
        cubit: cubit,
        home: Builder(
          builder: (context) => Scaffold(
            body: ConnectionBanner.maybeFor(context) ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.text("Connection Lost"), findsOneWidget);
    final alert = tester.widget<PregoInlineAlertsNotifications>(find.byType(PregoInlineAlertsNotifications));
    expect(alert.type, PregoInlineAlertsNotificationsType.error);
    expect(alert.icon, TablerRegular.cloud_off);
    expect(alert.primaryAction?.label, "Reconnect");

    await tester.tap(find.text("Reconnect"));
    await tester.pump();

    expect(cubit.reconnectCount, 1);
  });

  testWidgets("renders the warning alert with the bridge-disconnected title", (tester) async {
    final cubit = StubConnectionOverlayCubit(initialState: const ConnectionOverlayState.bridgeOffline());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      _app(cubit: cubit, home: const Scaffold(body: ConnectionBanner())),
    );

    expect(find.text("Bridge disconnected"), findsOneWidget);
    final alert = tester.widget<PregoInlineAlertsNotifications>(find.byType(PregoInlineAlertsNotifications));
    expect(alert.type, PregoInlineAlertsNotificationsType.warning);
    expect(alert.icon, TablerRegular.broadcast_off);
  });

  testWidgets("marks the offline banner as a live region so screen readers announce it", (tester) async {
    final handle = tester.ensureSemantics();
    final cubit = StubConnectionOverlayCubit(initialState: const ConnectionOverlayState.bridgeOffline());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      _app(cubit: cubit, home: const Scaffold(body: ConnectionBanner())),
    );

    // A live region is announced by VoiceOver/TalkBack when it appears without
    // moving focus — the whole point of the banner. The title stays a readable
    // text node inside it (so it's also navigable), so assert both.
    final banner = tester.getSemantics(find.byType(ConnectionBanner));
    expect(banner.flagsCollection.isLiveRegion, isTrue);
    expect(find.text("Bridge disconnected"), findsOneWidget);

    // Dispose in the body, not a tearDown: the framework verifies handle
    // disposal at the end of the test body, before tearDowns run.
    handle.dispose();
  });

  testWidgets("bridge going offline slides the banner into the top nav and back out on recovery", (tester) async {
    final cubit = _MutableConnectionOverlayCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      _app(
        cubit: cubit,
        home: Builder(
          builder: (context) => PregoGlassScaffold(
            title: "Sessions",
            inlineTitle: true,
            automaticallyImplyLeading: false,
            banner: ConnectionBanner.maybeFor(context),
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 10))],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ConnectionBanner), findsNothing);
    final restingBarTop = tester.getTopLeft(find.byType(GlassAppBar)).dy;

    cubit.setOverlayState(const ConnectionOverlayState.bridgeOffline());
    await tester.pumpAndSettle();

    expect(find.text("Bridge disconnected"), findsOneWidget);
    final bannerHeight = tester.getSize(find.byType(ConnectionBanner)).height;
    expect(bannerHeight, greaterThan(0));
    expect(tester.getTopLeft(find.byType(GlassAppBar)).dy, restingBarTop + bannerHeight);

    cubit.setOverlayState(const ConnectionOverlayState.hidden());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    // Mid-exit the retained banner content is still what slides away.
    expect(find.text("Bridge disconnected"), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text("Bridge disconnected"), findsNothing);
    expect(tester.getTopLeft(find.byType(GlassAppBar)).dy, restingBarTop);
  });

  testWidgets("a real screen's top nav hosts the banner when the bridge is offline", (tester) async {
    // Representative guard for the per-screen `banner:` wiring (session list;
    // detail/diffs/new-session/settings follow the identical pattern).
    final overlayCubit = StubConnectionOverlayCubit(initialState: const ConnectionOverlayState.bridgeOffline());
    addTearDown(overlayCubit.close);
    final sessionListCubit = _MockSessionListCubit();
    whenListen(
      sessionListCubit,
      const Stream<SessionListState>.empty(),
      initialState: const SessionListState.loading(),
    );

    await tester.pumpWidget(
      _app(
        cubit: overlayCubit,
        home: BlocProvider<SessionListCubit>.value(
          value: sessionListCubit,
          child: SessionListScaffold(
            onSessionTap: (_) {},
            sessionMenuEntries: (_, _) => const [],
            onSessionSwipe: (_) {},
            onNewSession: () {},
            onBack: null,
          ),
        ),
      ),
    );
    // No pumpAndSettle: the loading state's spinner animates indefinitely.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ConnectionBanner), findsOneWidget);
    expect(find.text("Bridge disconnected"), findsOneWidget);
  });
}
