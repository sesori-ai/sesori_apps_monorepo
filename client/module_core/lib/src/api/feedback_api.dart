import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../capabilities/feedback/feedback_submit_request.dart";

@lazySingleton
class FeedbackApi({required final AuthenticatedHttpApiClient _client}) {
  Future<void> submit({required FeedbackSubmitRequest request}) async {
    final response = await _client.post(
      Uri.parse("$authBaseUrl/feedback"),
      fromJson: (_) => true,
      body: request.toJson(),
    );
    if (response case ErrorResponse(:final error)) throw error;
  }
}
