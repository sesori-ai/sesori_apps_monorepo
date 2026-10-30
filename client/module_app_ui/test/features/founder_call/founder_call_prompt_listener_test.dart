import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  final bookingUrl = Uri.parse("https://cal.com/example");
  late StreamController<FounderCallSheetRequest> requests;
  late MockFounderCallService service;
  late List<(Uri, UrlLaunchMode)> opened;

  setUpAll(() => registerFallbackValue(FounderCallSurface.settings));

  setUp(() {
    requests = StreamController<FounderCallSheetRequest>.broadcast();
    service = MockFounderCallService();
    when(() => service.sheetRequests).thenAnswer((_) => requests.stream);
    when(() => service.recordLinkOpened(surface: any(named: "surface"))).thenAnswer((_) async {});
    opened = [];
  });

  tearDown(() => requests.close());

  Future<void> pumpListener({required WidgetTester tester}) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: buildPregoThemeData(brightness: Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => BlocProvider(
          create: (_) => FounderCallPromptCubit(founderCallService: service),
          child: FounderCallPromptListener(
            navigatorKey: navigatorKey,
            openExternalLink: ({required url, required mode}) async {
              opened.add((url, mode));
              return true;
            },
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const Text("Projects"),
      ),
    );
  }

  Future<void> requestSheet({required WidgetTester tester, required FounderCallCopy copy}) async {
    requests.add(FounderCallSheetRequest(bookingUrl: bookingUrl, copy: copy));
    await tester.pump();
    await tester.pump(founderCallSettleDelay);
    await tester.pumpAndSettle();
  }

  testWidgets("opens after the screen settles and books in the in-app browser", (tester) async {
    await pumpListener(tester: tester);
    requests.add(
      FounderCallSheetRequest(
        bookingUrl: bookingUrl,
        copy: const FounderCallCopy(title: null, message: null, buttonLabel: null),
      ),
    );
    await tester.pump();
    await tester.pump(founderCallSettleDelay - const Duration(milliseconds: 1));
    expect(find.text("Talk to the CEO"), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text("Talk to the CEO"), findsOneWidget);
    expect(find.text("Got 15 minutes? Tell me what you need from Sesori."), findsOneWidget);

    await tester.tap(find.byKey(const Key("founder_call_book")));
    await tester.pumpAndSettle();

    expect(opened, [(bookingUrl, UrlLaunchMode.inAppBrowser)]);
    verify(() => service.recordLinkOpened(surface: FounderCallSurface.computerConnectedSheet)).called(1);
    verifyNever(service.recordSheetDeclined);
  });

  testWidgets("uses the remote wording and records Not now as declined", (tester) async {
    await pumpListener(tester: tester);
    await requestSheet(
      tester: tester,
      copy: const FounderCallCopy(title: "Talk to the founder", message: "Pick a slot", buttonLabel: "Schedule"),
    );
    expect(find.text("Talk to the founder"), findsOneWidget);
    expect(find.text("Schedule"), findsOneWidget);

    await tester.tap(find.byKey(const Key("founder_call_not_now")));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    verify(service.recordSheetDeclined).called(1);
    expect(find.text("Talk to the founder"), findsNothing);
  });
}
