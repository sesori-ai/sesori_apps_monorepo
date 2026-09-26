import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../capabilities/feedback/feedback_submit_request.dart";

// The sheet blocks dismissal while a send is in flight, so a stalled request
// must fail rather than trap the user.
const _submitDeadline = Duration(seconds: 15);

@lazySingleton
class FeedbackApi({required final AuthenticatedHttpApiClient _client}) {
  Future<void> submit({required FeedbackSubmitRequest request}) async {
    final response = await _client
        .post(
          Uri.parse("$authBaseUrl/feedback"),
          fromJson: (_) => true,
          body: request.toJson(),
        )
        .timeout(_submitDeadline);
    if (response case ErrorResponse(:final error)) throw error;
  }
}
