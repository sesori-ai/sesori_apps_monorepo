/// The public legal pages opened from the settings "Legal" section.
///
/// The login screen links to the same two pages, but keeps its URLs inline in
/// the localized agreement sentence (`loginAgreementText`) because they are
/// part of that markdown copy.
class LegalLinks {
  const LegalLinks._();
  static const String terms = "https://sesori.com/terms";
  static const String privacy = "https://sesori.com/privacy";
}
