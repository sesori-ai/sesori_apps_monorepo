import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/desktop_route_source.dart";

void main() {
  test("starts without a route until the desktop router is installed", () async {
    final DesktopRouteSource source = DesktopRouteSource();
    addTearDown(source.dispose);

    expect(source.currentRouteStream.value, isNull);
    expect(source.currentLocation, isNull);
  });
}
