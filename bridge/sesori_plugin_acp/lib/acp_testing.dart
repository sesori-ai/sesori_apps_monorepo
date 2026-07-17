// Test utilities for ACP harness packages (FakeAcpProcess etc.). Import from
// test code only: `package:acp_plugin/acp_testing.dart`.
import "dart:async";

import "src/acp_stdio_client.dart";
import "src/api/acp_api.dart";
import "src/repositories/acp_notification_repository.dart";
import "src/repositories/models/acp_notification_record.dart";

export "src/testing/fake_acp_process.dart";

AcpNotificationRecord mapAcpNotificationForTest(AcpNotification notification) {
  return const AcpNotificationRepository(
    apiNotifications: Stream.empty(),
  ).map(
    AcpApi.parseNotification(notification),
  );
}
