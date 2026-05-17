import 'package:sesori_bridge/src/server/api/terminal_prompt_api.dart';
import 'package:sesori_bridge/src/server/foundation/terminal_prompt_decision.dart';
import 'package:sesori_bridge/src/server/repositories/terminal_prompt_repository.dart';
import 'package:test/test.dart';

void main() {
  group('TerminalPromptRepository', () {
    late _FakeTerminalPromptApi api;
    late TerminalPromptRepository repository;

    setUp(() {
      api = _FakeTerminalPromptApi();
      repository = TerminalPromptRepository(api: api);
    });

    test('non-interactive terminal returns nonInteractive without reading input', () async {
      api.isInteractiveValue = false;

      final decision = await repository.askReplaceExistingBridge(bridgeCount: 1);

      expect(decision, equals(TerminalPromptDecision.nonInteractive));
      expect(api.readCount, equals(0));
    });

    test('interactive y returns replace', () async {
      api.answer = ' y ';

      final decision = await repository.askReplaceExistingBridge(bridgeCount: 2);

      expect(decision, equals(TerminalPromptDecision.replace));
      expect(api.messages.single, equals('Another Sesori bridge is already running. Kill it and start fresh? [y/N]'));
    });

    test('interactive non-y answer returns decline', () async {
      api.answer = 'n';

      final decision = await repository.askReplaceExistingBridge(bridgeCount: 1);

      expect(decision, equals(TerminalPromptDecision.decline));
      expect(api.messages.single, equals('Another Sesori bridge is already running. Kill it and start fresh? [y/N]'));
    });
  });
}

class _FakeTerminalPromptApi implements TerminalPromptApi {
  bool isInteractiveValue = true;
  String? answer;
  int readCount = 0;
  final List<String> messages = <String>[];

  @override
  bool get isInteractive => isInteractiveValue;

  @override
  String? readLine({required String message, bool disableEcho = false}) {
    readCount += 1;
    messages.add(message);
    return answer;
  }
}
