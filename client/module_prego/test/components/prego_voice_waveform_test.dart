import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Widget app({required Widget child}) {
    return MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.dark]),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 200, child: child),
        ),
      ),
    );
  }

  testWidgets("paints within its band and keeps painting as samples arrive", (tester) async {
    final samples = StreamController<double>.broadcast();
    addTearDown(samples.close);

    await tester.pumpWidget(
      app(
        child: PregoVoiceWaveform(
          amplitudeStream: samples.stream,
          barColor: Colors.white,
          dotColor: Colors.grey,
        ),
      ),
    );

    final paintFinder = find.byType(CustomPaint).last;
    expect(paintFinder, findsOneWidget);
    expect(tester.getSize(find.byType(PregoVoiceWaveform)).height, 24);

    samples
      ..add(0.2)
      ..add(0.9);
    // The slide ticker never settles; bounded pumps only.
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
  });

  testWidgets("flatten progress scrubbing repaints without a rebuild", (tester) async {
    final samples = StreamController<double>.broadcast();
    addTearDown(samples.close);
    final flatten = ValueNotifier<double>(0);
    addTearDown(flatten.dispose);

    await tester.pumpWidget(
      app(
        child: PregoVoiceWaveform(
          amplitudeStream: samples.stream,
          barColor: Colors.white,
          dotColor: Colors.grey,
          flattenProgress: flatten,
        ),
      ),
    );
    samples.add(0.8);
    await tester.pump(const Duration(milliseconds: 50));

    flatten.value = 1;
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets("renders statically under reduced motion", (tester) async {
    final samples = StreamController<double>.broadcast();
    addTearDown(samples.close);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app(
          child: PregoVoiceWaveform(
            amplitudeStream: samples.stream,
            barColor: Colors.white,
            dotColor: Colors.grey,
          ),
        ),
      ),
    );
    samples.add(0.5);
    await tester.pump(const Duration(milliseconds: 50));

    // With the slide ticker suppressed there is nothing left animating, so
    // the tree settles — the reduced-motion contract.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

}
