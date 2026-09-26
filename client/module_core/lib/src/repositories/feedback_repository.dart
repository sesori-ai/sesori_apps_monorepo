import "package:injectable/injectable.dart";

import "../api/feedback_api.dart";
import "../api/installed_app_build_api.dart";
import "../capabilities/feedback/feedback_submit_request.dart";
import "../foundation/models/feedback/feedback_issue.dart";
import "../foundation/models/feedback/feedback_source.dart";

@lazySingleton
class FeedbackRepository({
  required final FeedbackApi _api,
  required final InstalledAppBuildApi _installedAppBuildApi,
}) {
  /// Sends private feedback. A blank [message] is left out, because the
  /// server accepts issues alone but rejects whitespace-only text.
  Future<void> submit({
    required Set<FeedbackIssue> issues,
    required String message,
    required FeedbackSource source,
  }) async {
    final trimmed = message.trim();
    await _api.submit(
      request: FeedbackSubmitRequest(
        issues: [
          for (final issue in FeedbackIssue.values)
            if (issues.contains(issue)) issue,
        ],
        message: trimmed.isEmpty ? null : trimmed,
        source: source,
        platform: _installedAppBuildApi.devicePlatform,
        appVersion: await _installedAppBuildApi.readVersion(),
      ),
    );
  }
}
