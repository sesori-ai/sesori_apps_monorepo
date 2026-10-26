import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/desktop_launch_arguments.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

void main() {
  test("recognizes only the exact hidden launch argument", () {
    expect(isDesktopHiddenLaunch(arguments: const <String>[]), isFalse);
    expect(isDesktopHiddenLaunch(arguments: const <String>["hidden"]), isFalse);
    expect(isDesktopHiddenLaunch(arguments: const <String>["--hidden=true"]), isFalse);
    expect(
      isDesktopHiddenLaunch(arguments: const <String>["--other", desktopHiddenLaunchArgument]),
      isTrue,
    );
  });

  test("recognizes only the exact after-update argument", () {
    expect(isDesktopAfterUpdateLaunch(arguments: const <String>[desktopHiddenLaunchArgument]), isFalse);
    expect(isDesktopAfterUpdateLaunch(arguments: const <String>["--after-update=true"]), isFalse);
    expect(isDesktopAfterUpdateLaunch(arguments: const <String>[desktopAfterUpdateLaunchArgument]), isTrue);
  });
}
