import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

/// Side chats carry prompt and answer text, so both routes keep their
/// responses out of error reports.
@lazySingleton
class SideChatApi({required final RelayHttpApiClient _client}) {
  /// Above the bridge's longest per-plugin bound for one side question, so
  /// the bridge's own answer or refusal arrives first.
  static const _askTimeout = Duration(minutes: 3, seconds: 30);

  Future<ApiResponse<SideChatListResponse>> listSideChats({required String sessionId}) => _client.postWithTimeout(
    "/session/side-chats",
    fromJson: SideChatListResponse.fromJson,
    body: SessionIdRequest(sessionId: sessionId),
    timeout: RelayHttpApiClient.defaultRequestTimeout,
  );

  Future<ApiResponse<AskSideQuestionResponse>> askSideQuestion({required AskSideQuestionRequest request}) =>
      _client.postWithTimeout(
        "/session/side-question",
        fromJson: AskSideQuestionResponse.fromJson,
        body: request,
        timeout: _askTimeout,
      );
}
