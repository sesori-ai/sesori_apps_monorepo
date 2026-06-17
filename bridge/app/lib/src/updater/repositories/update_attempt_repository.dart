import '../api/update_attempt_api.dart';
import '../models/update_attempt.dart';

/// Layer 2 wrapper over [UpdateAttemptApi]. Delegates persistence of the single
/// [UpdateAttempt] record used to reconcile in-place updates across launches.
class UpdateAttemptRepository {
  UpdateAttemptRepository({required UpdateAttemptApi api}) : _api = api;

  final UpdateAttemptApi _api;

  Future<UpdateAttempt?> readAttempt() => _api.read();

  Future<void> saveAttempt({required UpdateAttempt attempt}) => _api.write(attempt: attempt);

  Future<void> clearAttempt() => _api.clear();
}
