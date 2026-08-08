import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

/// Records the rounded rects the painter draws so tests can assert the
/// painted contract without goldens.
class _RecordingCanvas implements Canvas {
  final List<(RRect, Color)> rrects = [];

  @override
  void drawRRect(RRect rrect, Paint paint) => rrects.add((rrect, paint.color));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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

  testWidgets("paints recorded bars in the bar colour beside resting dots", (tester) async {
    const barColor = Color(0xFFFFFFFF);
    const dotColor = Color(0xFF9E9E9E);
    final samples = StreamController<double>.broadcast();
    addTearDown(samples.close);

    await tester.pumpWidget(
      app(
        child: PregoVoiceWaveform(
          amplitudeStream: samples.stream,
          barColor: barColor,
          dotColor: dotColor,
        ),
      ),
    );
    // Two samples: the newest bar is still growing in on the (real-time)
    // slide clock, so the settled full-amplitude bar is the previous one.
    samples
      ..add(1.0)
      ..add(0.0);
    await tester.pump(const Duration(milliseconds: 50));

    final painter = tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!;
    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(200, 24));

    final bars = canvas.rrects.where((r) => r.$2.toARGB32() == barColor.toARGB32()).toList();
    final dots = canvas.rrects.where((r) => r.$2.toARGB32() == dotColor.toARGB32()).toList();
    expect(bars, hasLength(2));
    // The settled full-amplitude bar spans the band; resting slots stay dots.
    expect(bars.map((r) => r.$1.height), contains(24));
    expect(dots.length, greaterThan(10));
    for (final (rrect, _) in dots) {
      expect(rrect.height, 6);
    }
  });

  testWidgets("full flatten progress paints every slot as a resting dot", (tester) async {
    const dotColor = Color(0xFF9E9E9E);
    final samples = StreamController<double>.broadcast();
    addTearDown(samples.close);
    final flatten = ValueNotifier<double>(0);
    addTearDown(flatten.dispose);

    await tester.pumpWidget(
      app(
        child: PregoVoiceWaveform(
          amplitudeStream: samples.stream,
          barColor: const Color(0xFFFFFFFF),
          dotColor: dotColor,
          flattenProgress: flatten,
        ),
      ),
    );
    samples.add(1.0);
    await tester.pump(const Duration(milliseconds: 50));
    flatten.value = 1;
    await tester.pump();

    final painter = tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!;
    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(200, 24));

    expect(canvas.rrects, isNotEmpty);
    for (final (rrect, color) in canvas.rrects) {
      expect(rrect.height, 6);
      expect(color.toARGB32(), dotColor.toARGB32());
    }
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
