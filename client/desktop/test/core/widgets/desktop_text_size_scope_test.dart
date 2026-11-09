import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/core/widgets/desktop_text_size_scope.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

void main() {
  setUpAll(() => registerFallbackValue(DesktopTextSize.standard));

  Future<DesktopTextSizeCubit> pumpScope(
    WidgetTester tester, {
    required _Repository repository,
    DesktopTextSize initialSize = DesktopTextSize.standard,
    FocusNode? field,
  }) async {
    final cubit = DesktopTextSizeCubit(
      repository: repository,
      appMenu: _SilentMenu(),
      initialSize: initialSize,
    );
    await tester.pumpWidget(
      // The provider closes the cubit with the tree, inside the test's clock.
      BlocProvider<DesktopTextSizeCubit>(
        create: (_) => cubit,
        child: MaterialApp(
          builder: (context, child) => DesktopTextSizeScope(child: child ?? const SizedBox.shrink()),
          home: Scaffold(
            body: field == null
                ? const Focus(autofocus: true, child: Text("Transcript"))
                : TextField(autofocus: true, focusNode: field),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  double scaleOf(WidgetTester tester) => MediaQuery.textScalerOf(tester.element(find.byType(Scaffold))).scale(10) / 10;

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  testWidgets("the chosen size multiplies the system's text scaling", (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final cubit = await pumpScope(tester, repository: _Repository.writable(), initialSize: DesktopTextSize.large);

    expect(scaleOf(tester), closeTo(1.2 * 1.15, 1e-9));

    await cubit.select(size: DesktopTextSize.small);
    await tester.pump();
    expect(scaleOf(tester), closeTo(1.2 * 0.9, 1e-9));
  });

  testWidgets(
    "zoom shortcuts step through the sizes, stop at the ends and reset to the default",
    (tester) async {
      final repository = _Repository.writable();
      final cubit = await pumpScope(tester, repository: repository);
      expect(scaleOf(tester), 1);

      await press(tester, LogicalKeyboardKey.equal);
      expect(cubit.state, DesktopTextSize.large);
      // Cmd/Ctrl++ is Shift+= on a US layout.
      await press(tester, LogicalKeyboardKey.equal, shift: true);
      expect(cubit.state, DesktopTextSize.larger);
      await press(tester, LogicalKeyboardKey.numpadAdd);
      expect(cubit.state, DesktopTextSize.larger);
      expect(scaleOf(tester), closeTo(1.3, 1e-9));

      await press(tester, LogicalKeyboardKey.digit0);
      expect(cubit.state, DesktopTextSize.standard);
      expect(scaleOf(tester), 1);

      for (var step = 0; step < 3; step++) {
        await press(tester, LogicalKeyboardKey.minus);
      }
      expect(cubit.state, DesktopTextSize.small);
      expect(scaleOf(tester), closeTo(0.9, 1e-9));

      verifyInOrder([
        () => repository.writeTextSize(size: DesktopTextSize.large),
        () => repository.writeTextSize(size: DesktopTextSize.larger),
        () => repository.writeTextSize(size: DesktopTextSize.standard),
        () => repository.writeTextSize(size: DesktopTextSize.small),
      ]);
      verifyNoMoreInteractions(repository);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.macOS, TargetPlatform.linux}),
  );

  testWidgets("the shortcuts work while typing, and an unmodified key types", (tester) async {
    final field = FocusNode();
    addTearDown(field.dispose);
    final cubit = await pumpScope(tester, repository: _Repository.writable(), field: field);
    expect(field.hasFocus, isTrue);

    await press(tester, LogicalKeyboardKey.equal);
    expect(cubit.state, DesktopTextSize.large);

    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pumpAndSettle();
    expect(cubit.state, DesktopTextSize.large);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}

class _Repository() extends Mock implements DesktopInstanceRepository {
  factory writable() {
    final repository = _Repository();
    when(() => repository.writeTextSize(size: any(named: "size"))).thenAnswer((_) async {});
    return repository;
  }
}

class _SilentMenu() implements DesktopAppMenu {
  @override
  Stream<DesktopAppMenuCommand> get commands => const Stream.empty();
}
