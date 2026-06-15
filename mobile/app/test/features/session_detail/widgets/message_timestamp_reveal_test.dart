import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/features/session_detail/widgets/message_timestamp_reveal.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_zyra/module_zyra.dart";

/// Hosts an [AnimationController] and hands it to [builder] so a test can
/// drive the reveal progress directly.
class _ControllerHost extends StatefulWidget {
  final Widget Function(AnimationController controller) builder;

  const _ControllerHost({required this.builder});

  @override
  State<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState extends State<_ControllerHost> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(controller);
}

void main() {
  const childKey = Key("row-child");
  const maxReveal = 76.0;

  Future<AnimationController> pumpReveal(WidgetTester tester, {required int? createdAtMs}) async {
    late AnimationController controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [ZyraDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: _ControllerHost(
            builder: (c) {
              controller = c;
              return MessageTimestampReveal(
                progress: c,
                maxReveal: maxReveal,
                createdAtMs: createdAtMs,
                child: const SizedBox(key: childKey, width: 200, height: 40),
              );
            },
          ),
        ),
      ),
    );
    return controller;
  }

  double childTranslationX(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.ancestor(of: find.byKey(childKey), matching: find.byType(Transform)).first,
    );
    return transform.transform.getTranslation().x;
  }

  double gutterRight(WidgetTester tester) {
    return tester.widget<Positioned>(find.byType(Positioned)).right!;
  }

  testWidgets("keeps content in place and the gutter off-screen while closed", (tester) async {
    await pumpReveal(tester, createdAtMs: DateTime.now().millisecondsSinceEpoch);

    expect(childTranslationX(tester), 0);
    // Gutter parked one full width beyond the right edge.
    expect(gutterRight(tester), -maxReveal);
  });

  testWidgets("slides content left and the gutter flush when fully revealed", (tester) async {
    final controller = await pumpReveal(tester, createdAtMs: DateTime.now().millisecondsSinceEpoch);

    controller.value = 1;
    await tester.pump();

    expect(childTranslationX(tester), -maxReveal);
    expect(gutterRight(tester), 0);
  });

  testWidgets("tracks partial progress proportionally", (tester) async {
    final controller = await pumpReveal(tester, createdAtMs: DateTime.now().millisecondsSinceEpoch);

    controller.value = 0.5;
    await tester.pump();

    expect(childTranslationX(tester), -maxReveal / 2);
    expect(gutterRight(tester), -maxReveal / 2);
  });

  testWidgets("renders a timestamp label when a creation time is present", (tester) async {
    final controller = await pumpReveal(tester, createdAtMs: DateTime.now().millisecondsSinceEpoch);
    controller.value = 1;
    await tester.pump();

    expect(
      find.descendant(of: find.byType(MessageTimestampReveal), matching: find.byType(Text)),
      findsOneWidget,
    );
  });

  testWidgets("renders no gutter when the row has no timestamp", (tester) async {
    await pumpReveal(tester, createdAtMs: null);

    expect(find.byType(Positioned), findsNothing);
    expect(find.descendant(of: find.byType(MessageTimestampReveal), matching: find.byType(Text)), findsNothing);
    // Still wraps the row so it slides with the rest of the transcript.
    expect(childTranslationX(tester), 0);
  });
}
