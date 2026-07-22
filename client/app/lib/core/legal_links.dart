import "package:sesori_dart_core/sesori_dart_core.dart";

/// The public web addresses of the legal documents.
///
/// The login screen's localized agreement sentence (`loginAgreementText`)
/// carries these URLs inline, because they are part of that markdown copy.
/// Tapping one opens the document in-app rather than in a browser, so
/// [documentFor] maps a tapped URL back to the document to show.
class LegalLinks {
  const LegalLinks._();
  static const String terms = "https://sesori.com/terms";
  static const String privacy = "https://sesori.com/privacy";

  /// The legal document [url] points at, or null when it is some other link.
  static LegalDocument? documentFor(String url) => switch (url) {
    terms => LegalDocument.terms,
    privacy => LegalDocument.privacy,
    _ => null,
  };
}
