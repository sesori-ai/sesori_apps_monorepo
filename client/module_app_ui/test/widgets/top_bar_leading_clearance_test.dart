import "dart:async";
import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

const _pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==";

/// Where a shell's controls end, such as the macOS traffic lights.
const _shellCorner = 84.0;

Widget _clearShellCorner({required Widget child}) => Padding(
  padding: const EdgeInsetsDirectional.only(start: _shellCorner),
  child: child,
);

/// Opens the image viewer on the root navigator, as a session does, with the
/// shell's clearance above that navigator when [clearance] is set.
Future<void> _openViewer({required WidgetTester tester, required bool clearance}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildPregoThemeData(brightness: Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => clearance
          ? TopBarLeadingClearance(wrap: _clearShellCorner, child: child ?? const SizedBox.shrink())
          : child ?? const SizedBox.shrink(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => unawaited(
              showImageAttachmentViewer(
                context: context,
                image: ViewOnlyMessageImage(provider: MemoryImage(base64Decode(_pngBase64)), originalUri: null),
                heroPresentation: ImageAttachmentHeroPresentation.contained,
                filename: "fixture.png",
                heroTag: const Key("fixture-image"),
              ),
            ),
            child: const Text("open"),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text("open"));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("the image viewer's close button starts past a shell's corner controls", (tester) async {
    await _openViewer(tester: tester, clearance: true);

    expect(tester.getTopLeft(find.byTooltip("Close image")).dx, greaterThanOrEqualTo(_shellCorner));
  });

  testWidgets("without a shell clearance the close button keeps its place", (tester) async {
    await _openViewer(tester: tester, clearance: false);

    expect(tester.getTopLeft(find.byTooltip("Close image")).dx, lessThan(_shellCorner / 2));
  });
}
