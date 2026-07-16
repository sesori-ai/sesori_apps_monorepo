import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_list/session_list_scaffold.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class _MockSessionListCubit extends MockCubit<SessionListState> implements SessionListCubit {}

/// The sessions-list top bar (Figma "Back Leading" type): project name over
/// the repo-slug subtitle row, connection dot bound to the overlay cubit, and
/// the full-slug info popover. The old collapsing large title is gone — the
/// bar block is the only title on the screen.
void main() {
  late _MockSessionListCubit cubit;

  setUp(() {
    cubit = _MockSessionListCubit();
  });

  Future<void> pumpScaffold(
    WidgetTester tester, {
    required SessionListState state,
    ConnectionOverlayState overlay = const ConnectionOverlayState.hidden(connected: true),
    String? projectName = "Sesori_app_monorepo",
  }) async {
    when(() => cubit.state).thenReturn(state);

    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>(
        create: (_) => StubConnectionOverlayCubit(initialState: overlay),
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<SessionListCubit>.value(
            value: cubit,
            child: SessionListScaffold(
              projectName: projectName,
              onBack: null,
              onNewSession: () {},
              onSessionTap: (_) {},
              sessionMenuEntries: (context, session) => const [],
              onSessionArchive: (_) {},
              onSessionDelete: (_) {},
              onSessionToggleUnread: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  SessionListState loadedState({
    required String? repoSlug,
    RepoProvider repoProvider = RepoProvider.other,
  }) => SessionListState.loaded(
    sessions: [testSession(id: "s1", title: "A task")],
    baseBranch: "main",
    repoSlug: repoSlug,
    repoProvider: repoProvider,
  );

  Color dotColor(WidgetTester tester) {
    // Scoped to the bar block — the page body renders circular containers of
    // its own (tile activity dots, buttons).
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(PregoNavLeadingTitle),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  testWidgets("bar shows the project name over the repo-slug subtitle row", (tester) async {
    await pumpScaffold(
      tester,
      state: loadedState(repoSlug: "sesori-ai/sesori_apps_monorepo", repoProvider: RepoProvider.github),
    );

    // Exactly one occurrence: the bar's leading block — no large title below.
    expect(find.text("Sesori_app_monorepo"), findsOneWidget);
    expect(find.text("sesori-ai/sesori_apps_monorepo"), findsOneWidget);
    expect(find.byIcon(TablerSolid.brand_github), findsOneWidget);
    expect(find.byType(PregoNavLeadingTitle), findsOneWidget);
  });

  testWidgets("subtitle row is hidden while no repo slug is known", (tester) async {
    await pumpScaffold(tester, state: loadedState(repoSlug: null));

    expect(find.text("Sesori_app_monorepo"), findsOneWidget);
    expect(find.byType(PregoNavSubtitle), findsNothing);
    expect(find.byType(PregoNavSubtitleSkeleton), findsNothing);
    expect(find.byIcon(TablerSolid.brand_github), findsNothing);
  });

  testWidgets("subtitle slot shimmers a skeleton pill while the list loads", (tester) async {
    await pumpScaffold(tester, state: const SessionListState.loading());
    // Past the skeleton's anti-flash appear delay (300ms). No pumpAndSettle:
    // the shimmer sweep animates indefinitely.
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.descendant(of: find.byType(PregoNavLeadingTitle), matching: find.byType(PregoNavSubtitleSkeleton)),
      findsOneWidget,
    );
    expect(find.byType(PregoNavSubtitle), findsNothing);
  });

  testWidgets("subtitle icon follows the recognised hosting provider", (tester) async {
    await pumpScaffold(
      tester,
      state: loadedState(repoSlug: "org/group/repo", repoProvider: RepoProvider.gitlab),
    );

    expect(find.byIcon(TablerRegular.brand_gitlab), findsOneWidget);
    expect(find.byIcon(TablerSolid.brand_github), findsNothing);
  });

  testWidgets("unrecognised providers fall back to the generic git icon", (tester) async {
    await pumpScaffold(tester, state: loadedState(repoSlug: "org/repo"));

    expect(find.byIcon(TablerRegular.brand_git), findsOneWidget);
  });

  testWidgets("falls back to the generic title without a project name", (tester) async {
    await pumpScaffold(tester, state: loadedState(repoSlug: "org/repo"), projectName: null);

    expect(find.text("Sessions"), findsOneWidget);
  });

  testWidgets("connection dot is green while fully connected", (tester) async {
    await pumpScaffold(tester, state: loadedState(repoSlug: "org/repo"));

    expect(dotColor(tester), PregoDesignSystem.light.colors.fgSuccessSecondary);
  });

  testWidgets("connection dot mutes while disconnected even though no banner shows", (tester) async {
    // hidden(connected: false) is the bannerless offline park: e.g. the user
    // chose Disconnect on the connection-lost card. Green would be a lie.
    await pumpScaffold(
      tester,
      state: loadedState(repoSlug: "org/repo"),
      overlay: const ConnectionOverlayState.hidden(connected: false),
    );

    expect(dotColor(tester), PregoDesignSystem.light.colors.fgDisabledSubtle);
  });

  testWidgets("connection dot mutes while the bridge is offline", (tester) async {
    await pumpScaffold(
      tester,
      state: loadedState(repoSlug: "org/repo"),
      overlay: const ConnectionOverlayState.bridgeOffline(),
    );
    // Let the banner's height animation land so the measured frame is stable.
    await tester.pump(const Duration(milliseconds: 400));

    expect(dotColor(tester), PregoDesignSystem.light.colors.fgDisabledSubtle);
  });

  testWidgets("tapping the subtitle row pops over the untruncated repo slug", (tester) async {
    await pumpScaffold(tester, state: loadedState(repoSlug: "sesori-ai/sesori_apps_monorepo"));

    await tester.tap(find.text("sesori-ai/sesori_apps_monorepo"));
    await tester.pumpAndSettle();

    // The popover shows the same (already-complete) slug — a second occurrence.
    expect(find.text("sesori-ai/sesori_apps_monorepo"), findsNWidgets(2));
  });
}
