import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_mobile/core/widgets/variant_picker_sheet.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";

Widget _buildApp({required ValueChanged<String?> onVariantChanged}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => Scaffold(
          body: FilledButton(
            onPressed: () => VariantPickerSheet.show(
              context,
              selectedVariant: null,
              availableVariants: const ["low", "xhigh"],
              onVariantChanged: onVariantChanged,
            ),
            child: const Text("Open picker"),
          ),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  testWidgets("shows default plus variants and returns the tapped selection", (tester) async {
    String? selectedVariant = "sentinel";

    await tester.pumpWidget(
      _buildApp(onVariantChanged: (variant) => selectedVariant = variant),
    );

    await tester.tap(find.text("Open picker"));
    await tester.pumpAndSettle();

    expect(find.text("Variant"), findsOneWidget);
    expect(find.text("Default"), findsOneWidget);
    expect(find.text("low"), findsOneWidget);
    expect(find.text("xhigh"), findsOneWidget);

    await tester.tap(find.text("low"));
    await tester.pumpAndSettle();

    expect(selectedVariant, "low");
    expect(find.text("Variant"), findsNothing);
  });

  testWidgets("selecting Default returns null", (tester) async {
    String? selectedVariant = "xhigh";

    await tester.pumpWidget(
      _buildApp(onVariantChanged: (variant) => selectedVariant = variant),
    );

    await tester.tap(find.text("Open picker"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Default"));
    await tester.pumpAndSettle();

    expect(selectedVariant, isNull);
  });
}
