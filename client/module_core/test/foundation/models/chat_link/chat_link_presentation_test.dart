import "package:sesori_dart_core/src/foundation/models/chat_link/chat_link_presentation.dart";
import "package:test/test.dart";

ChatLinkPresentation _bare(String url) => presentChatLink(href: url, text: url);

void main() {
  group("file references", () {
    test("show the file name with a type badge and the line", () {
      final presentation = presentChatLink(href: "lib/src/path.dart:12", text: "lib/src/path.dart:12");
      expect(presentation, isA<ChatFileLinkPresentation>());
      presentation as ChatFileLinkPresentation;
      expect(presentation.badge, FileTypeBadge.dart);
      expect(presentation.line, 12);
      expect(presentation.label, "path.dart (line 12)");
    });

    test("use the file name whatever the link text says", () {
      final presentation = presentChatLink(href: "/tmp/notes/release.md", text: "the notes");
      expect(presentation.label, "release.md");
    });

    test("badge common extensions, case-insensitively", () {
      FileTypeBadge? badgeOf(String path) =>
          (presentChatLink(href: path, text: path) as ChatFileLinkPresentation).badge;
      expect(badgeOf("a/b.TSX"), FileTypeBadge.tsx);
      expect(badgeOf("a/b.yml"), FileTypeBadge.yaml);
      expect(badgeOf("a/b.yaml"), FileTypeBadge.yaml);
      expect(badgeOf("a/run.sh"), FileTypeBadge.shell);
      expect(badgeOf("a/pubspec.lock"), isNull);
    });

    test("badge a Windows path", () {
      final presentation = presentChatLink(href: r"C:\src\app\main.ts:4", text: "x");
      expect((presentation as ChatFileLinkPresentation).badge, FileTypeBadge.typeScript);
      expect(presentation.label, "main.ts (line 4)");
      expect(presentChatLink(href: r"src\lib\util.py", text: "x").label, "util.py");
    });

    test("accept a file:// URI", () {
      expect(presentChatLink(href: "file:///Users/me/a.py", text: "x").label, "a.py");
    });
  });

  group("bare GitHub URLs", () {
    test("label a pull request", () {
      final presentation = _bare("https://github.com/acme/widgets/pull/2173");
      expect(presentation, isA<ChatGitHubLinkPresentation>());
      expect(presentation.label, "widgets PR #2173");
    });

    test("label an issue", () {
      expect(_bare("https://github.com/acme/widgets/issues/1240").label, "widgets #1240");
    });

    test("label a commit with its short hash", () {
      expect(_bare("https://github.com/acme/widgets/commit/49db6bd82fabcdef").label, "widgets @49db6bd");
    });

    test("label a pull request subpage", () {
      expect(_bare("https://github.com/acme/widgets/pull/7/files").label, "widgets PR #7");
    });

    test("show the host for any other GitHub page", () {
      final presentation = _bare("https://github.com/acme/widgets");
      expect(presentation, isA<ChatGitHubLinkPresentation>());
      expect(presentation.label, "github.com");
    });

    test("count an autolink written without its scheme as bare", () {
      expect(
        presentChatLink(href: "https://github.com/acme/widgets/pull/3", text: "github.com/acme/widgets/pull/3").label,
        "widgets PR #3",
      );
    });
  });

  group("other web links", () {
    test("show the host of a bare URL", () {
      final presentation = _bare("https://docs.flutter.dev/ui/layout");
      expect(presentation, isA<ChatWebLinkPresentation>());
      expect(presentation.label, "docs.flutter.dev");
    });

    test("keep their own text", () {
      final presentation = presentChatLink(href: "https://docs.flutter.dev", text: "the Flutter docs");
      expect(presentation, isA<ChatWebLinkPresentation>());
      expect(presentation.label, "the Flutter docs");
    });

    test("keep their own text on GitHub", () {
      final presentation = presentChatLink(href: "https://github.com/acme/widgets/pull/1", text: "the PR");
      expect(presentation, isA<ChatGitHubLinkPresentation>());
      expect(presentation.label, "the PR");
    });
  });

  test("other links keep their text with no icon", () {
    final presentation = presentChatLink(href: "mailto:team@example.com", text: "team@example.com");
    expect(presentation, isA<ChatPlainLinkPresentation>());
    expect(presentation.label, "team@example.com");
  });
}
