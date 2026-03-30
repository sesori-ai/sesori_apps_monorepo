import "package:opencode_plugin/opencode_plugin.dart";
import "package:test/test.dart";

void main() {
  group("sanitizeBranchName", () {
    test("converts title case to lowercase with hyphens", () {
      expect(sanitizeBranchName(raw: "Fix Login Bug"), equals("fix-login-bug"));
    });

    test("converts all uppercase to lowercase", () {
      expect(
        sanitizeBranchName(raw: "UPPERCASE TITLE"),
        equals("uppercase-title"),
      );
    });

    test("strips leading and trailing spaces", () {
      expect(sanitizeBranchName(raw: "  spaces  "), equals("spaces"));
    });

    test("removes special characters and converts to hyphens", () {
      expect(
        sanitizeBranchName(raw: "fix: handle edge case!!!"),
        equals("fix-handle-edge-case"),
      );
    });

    test("removes emoji and non-ASCII characters", () {
      expect(
        sanitizeBranchName(raw: "🚀 Deploy v2"),
        equals("deploy-v2"),
      );
    });

    test("collapses consecutive hyphens into single hyphen", () {
      expect(sanitizeBranchName(raw: "a--b---c"), equals("a-b-c"));
    });

    test("returns null for empty string", () {
      expect(sanitizeBranchName(raw: ""), isNull);
    });

    test("returns null for dots only", () {
      expect(sanitizeBranchName(raw: "..."), isNull);
    });

    test("strips trailing .lock suffix", () {
      expect(sanitizeBranchName(raw: "session.lock"), equals("session"));
    });

    test("truncates very long strings to 60 chars", () {
      final longString = "a" * 100;
      final result = sanitizeBranchName(raw: longString);
      expect(result, isNotNull);
      expect(result!.length, lessThanOrEqualTo(60));
    });

    test("truncates at hyphen boundary when possible", () {
      final longString = "very-long-branch-name-${"x" * 50}";
      final result = sanitizeBranchName(raw: longString);
      expect(result, isNotNull);
      expect(result!.length, lessThanOrEqualTo(60));
      expect(result.endsWith("-"), isFalse);
    });

    test("converts slashes to hyphens", () {
      expect(
        sanitizeBranchName(raw: "feat/dark-mode"),
        equals("feat-dark-mode"),
      );
    });

    test("returns null for whitespace only", () {
      expect(sanitizeBranchName(raw: "   "), isNull);
    });

    test("returns null for emoji only", () {
      expect(sanitizeBranchName(raw: "🚀🎉"), isNull);
    });

    test("rejects strings containing double dots", () {
      expect(sanitizeBranchName(raw: "feat..branch"), isNull);
    });

    test("strips trailing dots", () {
      expect(sanitizeBranchName(raw: "branch."), equals("branch"));
    });

    test("strips trailing dots before .lock check", () {
      expect(sanitizeBranchName(raw: "session.lock."), equals("session"));
    });

    test("handles mixed case with numbers", () {
      expect(
        sanitizeBranchName(raw: "Feature-123-ABC"),
        equals("feature-123-abc"),
      );
    });

    test("preserves numbers in output", () {
      expect(
        sanitizeBranchName(raw: "v2.0.1 release"),
        equals("v201-release"),
      );
    });

    test("handles underscores as hyphens", () {
      expect(
        sanitizeBranchName(raw: "fix_bug_now"),
        equals("fix-bug-now"),
      );
    });

    test("handles mixed spaces and underscores", () {
      expect(
        sanitizeBranchName(raw: "fix_the bug now"),
        equals("fix-the-bug-now"),
      );
    });

    test("returns null if result is empty after sanitization", () {
      expect(sanitizeBranchName(raw: "!!!"), isNull);
    });

    test("handles leading hyphens removal", () {
      expect(sanitizeBranchName(raw: "---branch"), equals("branch"));
    });

    test("handles trailing hyphens removal", () {
      expect(sanitizeBranchName(raw: "branch---"), equals("branch"));
    });

    test("handles both leading and trailing hyphens", () {
      expect(sanitizeBranchName(raw: "---branch---"), equals("branch"));
    });

    test("handles complex real-world example", () {
      expect(
        sanitizeBranchName(raw: "🎯 Fix: Handle edge cases in login flow!!!"),
        equals("fix-handle-edge-cases-in-login-flow"),
      );
    });

    test("handles single character", () {
      expect(sanitizeBranchName(raw: "a"), equals("a"));
    });

    test("handles single character that is special", () {
      expect(sanitizeBranchName(raw: "!"), isNull);
    });

    test("handles exactly 60 character string", () {
      final str = "a" * 60;
      final result = sanitizeBranchName(raw: str);
      expect(result, equals(str));
      expect(result!.length, equals(60));
    });

    test("handles 61 character string truncation", () {
      final str = "a" * 61;
      final result = sanitizeBranchName(raw: str);
      expect(result, isNotNull);
      expect(result!.length, lessThanOrEqualTo(60));
    });

    test("handles hyphenated string longer than 60 chars", () {
      final str = "word-" * 20; // Creates "word-word-word-..." pattern
      final result = sanitizeBranchName(raw: str);
      expect(result, isNotNull);
      expect(result!.length, lessThanOrEqualTo(60));
      expect(result.endsWith("-"), isFalse);
    });

    test("rejects double dots in middle", () {
      expect(sanitizeBranchName(raw: "feat..branch"), isNull);
    });

    test("rejects double dots at start", () {
      expect(sanitizeBranchName(raw: "..branch"), isNull);
    });

    test("rejects double dots at end", () {
      expect(sanitizeBranchName(raw: "branch.."), equals("branch"));
    });

    test("handles .lock in middle of string", () {
      expect(
        sanitizeBranchName(raw: "session.lock.backup"),
        equals("sessionlockbackup"),
      );
    });

    test("handles multiple .lock suffixes", () {
      expect(
        sanitizeBranchName(raw: "session.lock.lock"),
        equals("sessionlock"),
      );
    });

    test("handles tab and newline characters", () {
      expect(
        sanitizeBranchName(raw: "fix\tbug\nhere"),
        equals("fixbughere"),
      );
    });

    test("handles unicode letters (non-ASCII)", () {
      expect(sanitizeBranchName(raw: "café"), equals("caf"));
    });

    test("handles mixed ASCII and non-ASCII", () {
      expect(
        sanitizeBranchName(raw: "fix café bug"),
        equals("fix-caf-bug"),
      );
    });
  });
}
