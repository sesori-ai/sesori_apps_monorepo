import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_list/session_list_panel.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

/// Layout guards for [SessionListPanel]'s header.
///
/// The panel only ever renders in the wide split layout's list pane, which in
/// landscape can be as narrow as ~226pt. The header's back + archive + a
/// labelled "New session" button used to starve the [Expanded] title to zero
/// width, wrapping it one glyph per line and overflowing the row across and
/// down. The header now collapses the labelled button to an icon when narrow
/// and ellipsizes the title, so it must lay out cleanly at split-pane widths.
class _MockSessionListCubit extends MockCubit<SessionListState> implements SessionListCubit {}

void main() {
  late _MockSessionListCubit cubit;

  setUp(() {
    cubit = _MockSessionListCubit();
    when(() => cubit.state).thenReturn(
      const SessionListState.loaded(sessions: [], baseBranch: null),
    );
  });

  // Renders the real panel at a fixed width; the header sits inside the panel's
  // own 16pt horizontal padding, so the header content width is [width] - 32.
  Future<void> pumpPanel(WidgetTester tester, {required double width}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: PregoColors.light.toFlutterColorScheme(),
          textTheme: PregoTextTheme.light.asFlutterTextTheme(),
          extensions: [PregoDesignSystem.light],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<SessionListCubit>.value(
            value: cubit,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 800,
                child: SessionListPanel(
                  // A long name maximises title pressure on the narrow header.
                  projectName: "A Fairly Long Project Name That Will Not Fit",
                  onBack: () {},
                  onNewSession: () {},
                  onSessionTap: (_) {},
                  onSessionLongPress: (_) {},
                  onSessionSwipe: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String newSessionLabel(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(SessionListPanel)))!.sessionListNewSession;

  testWidgets("narrow landscape pane lays out the header without overflow", (tester) async {
    // 258 - 32pt padding = 226pt header — the narrowest real split pane, where
    // the labelled layout used to overflow by 25px across and 310px down.
    await pumpPanel(tester, width: 258);

    expect(tester.takeException(), isNull);
    // The action collapses to an icon-only button so the title keeps its width;
    // its label moves to the tooltip (no visible label Text).
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text(newSessionLabel(tester)), findsNothing);
  });

  testWidgets("wide pane keeps the labelled New session button", (tester) async {
    // Wide enough that the labelled button is chosen and has ample room. (The
    // desktop list pane floors at 320pt → ~288pt header, comfortably above the
    // 280pt collapse threshold, so desktop always keeps the label. That floor
    // can't be asserted here: the fixed-width test font renders "New session"
    // far wider than the real font, which would overflow a snug header only in
    // tests — the real-font fit is verified on-device.)
    await pumpPanel(tester, width: 600);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text(newSessionLabel(tester)), findsOneWidget);
  });
}
