import "dart:async";

import "package:desktop_drop/desktop_drop.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_desktop/core/widgets/desktop_composer_presentation_scope.dart";
import "package:sesori_desktop/core/widgets/desktop_pane_drop_target.dart";
import "package:theme_prego/module_prego.dart";

/// Stands in for a composer: listens to the pane's drops while mounted, and
/// pauses them while [_paused] (recording, for a real composer).
class const _Listener({
  required final List<List<String>> _received,
  final bool _paused = false,
}) extends StatefulWidget {
  @override
  State<_Listener> createState() => _ListenerState();
}

class _ListenerState() extends State<_Listener> {
  StreamSubscription<List<String>>? _subscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription ??= ComposerPresentationScope.of(context).droppedPaths?.listen(widget._received.add);
    if (widget._paused) _subscription?.pause();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

final _details = DropEventDetails(localPosition: Offset.zero, globalPosition: Offset.zero);

void main() {
  Future<void> pumpPane(WidgetTester tester, {required List<Widget> children}) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DesktopPaneDropTarget(
        child: DesktopComposerPresentationScope(child: Column(children: children)),
      ),
    ),
  );

  DropTarget dropTarget(WidgetTester tester) => tester.widget<DropTarget>(find.byType(DropTarget));

  double hintOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: find.text("Drop files to add them to your prompt"), matching: find.byType(AnimatedOpacity)),
      )
      .opacity;

  void drop(WidgetTester tester) => dropTarget(tester).onDragDone?.call(
    DropDoneDetails(
      files: [DropItemFile("/work/notes.dart"), DropItemDirectory("/work/lib", [])],
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
    ),
  );

  testWidgets("hints and delivers only while a composer listens, keeping the hint in step", (tester) async {
    await pumpPane(tester, children: const [Spacer()]);

    dropTarget(tester).onDragEntered?.call(_details);
    await tester.pumpAndSettle();
    expect(hintOpacity(tester), 0);

    // A composer that appears mid-drag shows the hint without a new drag.
    final received = <List<String>>[];
    await pumpPane(
      tester,
      children: [Expanded(child: _Listener(received: received))],
    );
    await tester.pumpAndSettle();
    expect(hintOpacity(tester), 1);

    drop(tester);
    await tester.pumpAndSettle();
    expect(received, [
      ["/work/notes.dart", "/work/lib"],
    ]);
    expect(hintOpacity(tester), 0);
  });

  testWidgets("a drop with no composer listening shows a notice", (tester) async {
    await pumpPane(tester, children: const [Spacer()]);

    drop(tester);
    await tester.pump();

    expect(find.text("Files can't be added here"), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets("a paused composer shows no hint and its drop gets a notice", (tester) async {
    final received = <List<String>>[];
    await pumpPane(
      tester,
      children: [Expanded(child: _Listener(received: received, paused: true))],
    );

    dropTarget(tester).onDragEntered?.call(_details);
    await tester.pumpAndSettle();
    expect(hintOpacity(tester), 0);

    drop(tester);
    await tester.pump();

    expect(find.text("Finish recording before adding files"), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(received, isEmpty);
  });

  testWidgets("a drop reaches only the composer that listened last", (tester) async {
    final outgoing = <List<String>>[];
    final incoming = <List<String>>[];
    await pumpPane(
      tester,
      children: [Expanded(child: _Listener(received: outgoing))],
    );
    await pumpPane(
      tester,
      children: [
        Expanded(child: _Listener(received: outgoing)),
        Expanded(child: _Listener(received: incoming)),
      ],
    );

    drop(tester);
    await tester.pump();

    expect(outgoing, isEmpty);
    expect(incoming, hasLength(1));
  });

  testWidgets("a pane under another page takes no drops", (tester) async {
    final received = <List<String>>[];
    await pumpPane(
      tester,
      children: [Expanded(child: _Listener(received: received))],
    );
    final pane = dropTarget(tester);
    Navigator.of(tester.element(find.byType(_Listener))).push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
    );
    await tester.pumpAndSettle();

    pane.onDragEntered?.call(_details);
    pane.onDragDone?.call(
      DropDoneDetails(
        files: [DropItemFile("/work/notes.dart")],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pump();

    expect(received, isEmpty);
  });
}
