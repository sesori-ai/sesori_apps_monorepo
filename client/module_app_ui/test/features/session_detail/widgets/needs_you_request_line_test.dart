import "package:flutter_test/flutter_test.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_detail_loaded_view.dart";

void main() {
  test("a needs-you card previews a request's first line as plain text", () {
    expect(
      needsYouRequestLine(
        text:
            "**Turns on Approve everything: this task's runs will act without asking you.**\n\n"
            "Project: `sesori`",
      ),
      "Turns on Approve everything: this task's runs will act without asking you.",
    );
    expect(needsYouRequestLine(text: "  # Run *the* `ls` command"), "Run the ls command");
    expect(needsYouRequestLine(text: "- Delete **build/**"), "Delete build/");
    expect(needsYouRequestLine(text: "Run rm -rf build"), "Run rm -rf build");
  });
}
