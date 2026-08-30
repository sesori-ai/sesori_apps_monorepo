import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/widgets/desktop_sse_toast_listener.dart";
import "package:theme_prego/module_prego.dart";

class _MockConnectionService() extends Mock implements ConnectionService;

class _EmptyRouteSource() implements RouteSource {
  final BehaviorSubject<AppRouteDef?> _route = BehaviorSubject.seeded(null);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _route.stream;

  @override
  String? get currentLocation => null;

  Future<void> dispose() => _route.close();
}

void main() {
  testWidgets("presents a backend toast on the desktop navigator overlay", (WidgetTester tester) async {
    final _MockConnectionService connectionService = _MockConnectionService();
    when(() => connectionService.events).thenAnswer((_) => const Stream.empty());
    final _EmptyRouteSource routeSource = _EmptyRouteSource();
    final SseToastCubit cubit = SseToastCubit(
      connectionService: connectionService,
      routeSource: routeSource,
    );
    addTearDown(cubit.close);
    addTearDown(routeSource.dispose);
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      BlocProvider<SseToastCubit>.value(
        value: cubit,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: buildPregoThemeData(brightness: Brightness.light),
          home: DesktopSseToastListener(
            navigatorKey: navigatorKey,
            child: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      ),
    );
    await tester.pump();

    cubit.emit(
      const SseToastState.show(
        sequence: 1,
        title: "Backend notice",
        message: "A bridge event arrived",
        variant: SseToastVariant.info,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(navigatorKey.currentState, isNotNull);
    expect(navigatorKey.currentState?.overlay, isNotNull);
    expect(find.text("Backend notice"), findsOneWidget);
    expect(find.text("A bridge event arrived"), findsOneWidget);
  });
}
