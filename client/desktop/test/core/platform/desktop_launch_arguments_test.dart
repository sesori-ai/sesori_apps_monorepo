import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/desktop_launch_arguments.dart";

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
}
