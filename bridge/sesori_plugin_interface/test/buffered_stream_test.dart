import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("BufferedUntilFirstListener", () {
    test("delivers buffered events in order to the first listener", () async {
      final buffered = BufferedUntilFirstListener<int>();
      buffered.add(1);
      buffered.add(2);
      await buffered.close();

      await expectLater(buffered.stream, emitsInOrder([1, 2, emitsDone]));
    });

    test("delivers live events to multiple listeners", () async {
      final buffered = BufferedUntilFirstListener<int>();
      final first = expectLater(buffered.stream, emitsInOrder([1, 2, emitsDone]));
      final second = expectLater(buffered.stream, emitsInOrder([1, 2, emitsDone]));

      buffered.add(1);
      buffered.add(2);
      await buffered.close();

      await Future.wait<void>([first, second]);
    });

    test("allows another listener after an earlier listener cancels", () async {
      final buffered = BufferedUntilFirstListener<int>();
      final firstEvent = Completer<int>();
      final firstSubscription = buffered.stream.listen(firstEvent.complete);

      buffered.add(1);
      expect(await firstEvent.future, 1);
      await firstSubscription.cancel();

      final later = expectLater(buffered.stream, emitsInOrder([2, emitsDone]));
      buffered.add(2);
      await buffered.close();

      await later;
    });
  });
}
