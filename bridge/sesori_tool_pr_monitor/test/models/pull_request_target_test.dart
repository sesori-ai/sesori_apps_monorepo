import "package:sesori_tool_pr_monitor/sesori_tool_pr_monitor.dart";
import "package:test/test.dart";

void main() {
  test("parses the short form", () {
    final target = PullRequestTarget.parse(input: " Octo-Org/Widget.js#42 ");

    expect(target, const PullRequestTarget(owner: "Octo-Org", repo: "Widget.js", number: 42));
    expect(target.displayKey, "Octo-Org/Widget.js#42");
    expect(target.registryKey, "octo-org/widget.js#42");
    expect(target.url, "https://github.com/Octo-Org/Widget.js/pull/42");
  });

  test("parses a PR URL with a trailing path, query or fragment", () {
    for (final input in [
      "https://github.com/octo-org/widget/pull/7",
      "https://github.com/octo-org/widget/pull/7/files",
      "https://github.com/octo-org/widget/pull/7?w=1",
      "https://github.com/octo-org/widget/pull/7#discussion_r1",
    ]) {
      expect(
        PullRequestTarget.parse(input: input),
        const PullRequestTarget(owner: "octo-org", repo: "widget", number: 7),
      );
    }
  });

  test("rejects anything that does not name the repository explicitly", () {
    for (final input in ["#42", "widget#42", "octo-org/widget", "-octo/widget#1", "https://gitlab.com/o/r/pull/1"]) {
      expect(
        () => PullRequestTarget.parse(input: input),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            "message",
            'Invalid PR identifier: "$input". Use "owner/repo#123" or a full PR URL '
                "(https://github.com/owner/repo/pull/123). The repo must always be explicit.",
          ),
        ),
      );
    }
  });
}
