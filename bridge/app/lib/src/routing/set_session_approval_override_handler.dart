import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../services/session_view_service.dart";
import "../services/yolo_settings_service.dart";
import "request_handler.dart";

/// Handles `PATCH /session/approval-override` — sets or clears whether one
/// session asks for approval or runs in YOLO, regardless of the bridge
/// setting.
class SetSessionApprovalOverrideHandler({
  required final YoloSettingsService _yoloSettingsService,
  required final SessionViewService _sessionViews,
}) extends BodyRequestHandler<SetSessionApprovalOverrideRequest, Session> {
  this
    : super(
        HttpMethod.patch,
        "/session/approval-override",
        fromJson: SetSessionApprovalOverrideRequest.fromJson,
      );

  @override
  Future<Session> handle(
    RelayRequest request, {
    required SetSessionApprovalOverrideRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    final Session session;
    try {
      session = await _yoloSettingsService.setSessionOverride(
        sessionId: body.sessionId,
        approvalOverride: body.approvalOverride,
      );
    } on PluginOperationException catch (error) {
      if (!error.isNotFound) rethrow;
      // A body, unlike the bare 404 an older bridge returns for this unknown
      // route, lets the app tell a missing session from an unsupported request.
      throw buildJsonErrorResponse(
        request: request,
        status: 404,
        body: const SessionApprovalOverrideErrorResponse(
          code: SessionApprovalOverrideErrorCode.sessionNotFound,
        ).toJson(),
      );
    }
    return await _sessionViews.enrich(session: session);
  }
}
