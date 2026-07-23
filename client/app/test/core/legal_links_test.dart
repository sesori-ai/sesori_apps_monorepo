import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/legal_links.dart";
import "package:sesori_mobile/l10n/app_localizations_en.dart";

/// Markdown inline links: `[label](url)`.
final _markdownLink = RegExp(r"\[[^\]]+\]\(([^)]+)\)");

void main() {
  test("every link in the login agreement resolves to a legal document", () {
    // The agreement copy carries the URLs inline, so a drift between that copy
    // and [LegalLinks] would silently send the user to the browser instead of
    // opening the document sheet.
    final urls = _markdownLink
        .allMatches(AppLocalizationsEn().loginAgreementText)
        .map((match) => match.group(1)!)
        .toList();

    expect(urls, isNotEmpty);
    expect(
      urls.map(LegalLinks.documentFor),
      [LegalDocument.terms, LegalDocument.privacy],
    );
  });

  test("an unrelated link is not treated as a legal document", () {
    expect(LegalLinks.documentFor("https://sesori.com"), isNull);
  });
}
