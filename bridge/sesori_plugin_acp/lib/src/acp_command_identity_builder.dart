/// Builds stable identities shared by live ACP commands and history replay.
abstract final class AcpCommandIdentityBuilder {
  static String messageId({
    required String sessionId,
    required String invocationId,
  }) => "$sessionId-command-$invocationId";

  static String resultPartId({required String commandMessageId}) => "$commandMessageId-result";
}
