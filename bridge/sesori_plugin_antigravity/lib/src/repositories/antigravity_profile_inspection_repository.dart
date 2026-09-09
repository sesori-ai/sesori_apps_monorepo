import "../storage/antigravity_profile_inspection_storage.dart";

/// Maps the read-only profile boundary without exposing token contents.
class AntigravityProfileInspectionRepository({required final AntigravityProfileInspectionStorage _storage}) {
  bool hasToken({required String geminiHome}) => _storage.tokenExists(geminiHome: geminiHome);
}
