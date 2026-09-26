import "package:flutter_test/flutter_test.dart";
import "package:sesori_app_ui/src/features/project_list/widgets/project_tile.dart";

void main() {
  test("hostPathBasename returns the last folder for either separator", () {
    expect(hostPathBasename(path: "/Users/me/app"), "app");
    expect(hostPathBasename(path: r"C:\work\app"), "app");
  });

  test("hostPathBasename keeps a Windows drive root whole", () {
    expect(hostPathBasename(path: r"C:\"), r"C:\");
    expect(hostPathBasename(path: "C:/"), "C:/");
  });
}
