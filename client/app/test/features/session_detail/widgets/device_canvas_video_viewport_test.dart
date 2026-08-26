import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_detail/widgets/device_canvas_video_viewport.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("shows a connecting LAN-only video surface", (tester) async {
    await tester.pumpWidget(_app(state: const DeviceCanvasVideoConnecting()));

    expect(find.text("Android Emulator"), findsOneWidget);
    expect(find.text("LAN video preview"), findsOneWidget);
    expect(find.text("Connecting to Device Canvas..."), findsOneWidget);
    expect(find.byKey(const Key("video-surface")), findsOneWidget);
    expect(find.textContaining("same local network"), findsOneWidget);
  });

  testWidgets("shows live state and closes explicitly", (tester) async {
    var closes = 0;
    await tester.pumpWidget(
      _app(
        state: const DeviceCanvasVideoLive(expiresAt: 123),
        onClose: () => closes++,
      ),
    );

    expect(find.text("Live"), findsOneWidget);
    await tester.tap(find.text("Close preview"));

    expect(closes, 1);
  });

  testWidgets("explains when a response requires TURN", (tester) async {
    await tester.pumpWidget(
      _app(
        state: const DeviceCanvasVideoFailed(reason: DeviceCanvasVideoFailureReason.lanOnly),
      ),
    );

    expect(find.text("This preview is limited to local-network connections."), findsOneWidget);
  });
}

Widget _app({required DeviceCanvasVideoState state, VoidCallback? onClose}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DeviceCanvasVideoViewport(
        state: state,
        deviceName: "Android Emulator",
        videoSurface: const SizedBox(key: Key("video-surface")),
        onClose: onClose ?? () {},
      ),
    ),
  );
}
