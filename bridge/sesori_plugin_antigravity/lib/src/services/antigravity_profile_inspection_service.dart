import "../models/antigravity_profile.dart";
import "../repositories/antigravity_profile_inspection_repository.dart";

/// Owns setup-readiness policy for the selected isolated profile.
class AntigravityProfileInspectionService({required final AntigravityProfileInspectionRepository _repository}) {
  AntigravityAuthenticationHint inspect({required String geminiHome}) => _repository.hasToken(geminiHome: geminiHome)
      ? AntigravityAuthenticationHint.tokenPresent
      : AntigravityAuthenticationHint.authenticationRequired;
}
