import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

class _MockConnectionOverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit {
  int reconnectCalls = 0;

  @override
  void reconnect() => reconnectCalls++;
}

void main() {
  Future<void> pumpBanner({required WidgetTester tester, required _MockConnectionOverlayCubit cubit}) async {
    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ConnectionBanner.maybeFor(context) ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("renders bridge-offline warning", (WidgetTester tester) async {
    final _MockConnectionOverlayCubit cubit = _MockConnectionOverlayCubit();
    addTearDown(cubit.close);
    whenListen(
      cubit,
      const Stream<ConnectionOverlayState>.empty(),
      initialState: const ConnectionOverlayState.bridgeOffline(),
    );

    await pumpBanner(tester: tester, cubit: cubit);

    expect(find.text("Bridge disconnected"), findsOneWidget);
    expect(find.byType(PregoInlineAlertsNotifications), findsOneWidget);
  });

  testWidgets("renders connection-lost retry and delegates to the cubit", (WidgetTester tester) async {
    final _MockConnectionOverlayCubit cubit = _MockConnectionOverlayCubit();
    addTearDown(cubit.close);
    whenListen(
      cubit,
      const Stream<ConnectionOverlayState>.empty(),
      initialState: const ConnectionOverlayState.connectionLost(),
    );

    await pumpBanner(tester: tester, cubit: cubit);

    expect(find.text("Connection Lost"), findsOneWidget);
    expect(find.text("Reconnect"), findsOneWidget);
    await tester.tap(find.text("Reconnect"));
    expect(cubit.reconnectCalls, 1);
  });

  testWidgets("renders the reconnecting warning without an action", (WidgetTester tester) async {
    final _MockConnectionOverlayCubit cubit = _MockConnectionOverlayCubit();
    addTearDown(cubit.close);
    whenListen(
      cubit,
      const Stream<ConnectionOverlayState>.empty(),
      initialState: const ConnectionOverlayState.reconnecting(),
    );

    await pumpBanner(tester: tester, cubit: cubit);

    expect(find.text("Reconnecting…"), findsOneWidget);
    expect(find.text("Reconnect"), findsNothing);
  });

  testWidgets("does not render for hidden states", (WidgetTester tester) async {
    for (final ConnectionOverlayState state in <ConnectionOverlayState>[
      const ConnectionOverlayState.hidden(connected: true),
      const ConnectionOverlayState.hidden(connected: false),
    ]) {
      final _MockConnectionOverlayCubit cubit = _MockConnectionOverlayCubit();
      addTearDown(cubit.close);
      whenListen(cubit, const Stream<ConnectionOverlayState>.empty(), initialState: state);
      await pumpBanner(tester: tester, cubit: cubit);
      expect(find.byType(ConnectionBanner), findsNothing);
    }
  });
}
