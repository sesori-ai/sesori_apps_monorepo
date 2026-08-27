import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/capabilities/voice/wake_lock_service.dart";

void main() {
  test("keeps the global wake lock until the final overlapping session releases", () async {
    var enableCalls = 0;
    var disableCalls = 0;
    final service = WakeLockService(
      enable: () async {
        enableCalls++;
      },
      disable: () async {
        disableCalls++;
      },
    );

    final first = service.acquire();
    final second = service.acquire();
    await Future<void>.delayed(Duration.zero);

    expect(enableCalls, 1);
    await first.release();
    expect(disableCalls, 0);

    await second.release();
    expect(disableCalls, 1);
  });

  test("serializes final release behind an in-flight global enable", () async {
    final enableCompleter = Completer<void>();
    var disableCalls = 0;
    final service = WakeLockService(
      enable: () => enableCompleter.future,
      disable: () async {
        disableCalls++;
      },
    );

    final first = service.acquire();
    final second = service.acquire();
    await first.release();
    final finalRelease = second.release();
    await Future<void>.delayed(Duration.zero);
    expect(disableCalls, 0);

    enableCompleter.complete();
    await finalRelease;
    expect(disableCalls, 1);
  });

  test("a session lease releases idempotently", () async {
    var disableCalls = 0;
    final service = WakeLockService(
      enable: () async {},
      disable: () async {
        disableCalls++;
      },
    );
    final lease = service.acquire();

    await lease.release();
    await lease.release();

    expect(disableCalls, 1);
  });
}
