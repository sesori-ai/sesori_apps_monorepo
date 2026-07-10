import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const ControlPromptRequest _replacePrompt = ControlPromptRequest(
  id: "p1",
  kind: ControlPromptKind.replaceBridge,
  message: "Another Sesori bridge is already running. Kill it and start fresh?",
);

const ControlPromptRequest _loginPrompt = ControlPromptRequest(
  id: "p2",
  kind: ControlPromptKind.loginNeeded,
  message: null,
);

void main() {
  late BridgePromptTracker tracker;

  setUp(() {
    tracker = BridgePromptTracker();
    addTearDown(tracker.dispose);
  });

  test("defaults to no pending prompts", () {
    expect(tracker.prompts, isEmpty);
  });

  test("addPrompt records prompts in arrival order", () {
    tracker.addPrompt(prompt: _replacePrompt);
    tracker.addPrompt(prompt: _loginPrompt);

    expect(tracker.prompts, [_replacePrompt, _loginPrompt]);
  });

  test("a resent prompt id replaces the original", () {
    tracker.addPrompt(prompt: _replacePrompt);
    const ControlPromptRequest resent = ControlPromptRequest(
      id: "p1",
      kind: ControlPromptKind.replaceBridge,
      message: "resent",
    );

    tracker.addPrompt(prompt: resent);

    expect(tracker.prompts, [resent]);
  });

  test("removePrompt drops only the answered prompt", () {
    tracker.addPrompt(prompt: _replacePrompt);
    tracker.addPrompt(prompt: _loginPrompt);

    tracker.removePrompt(id: "p1");

    expect(tracker.prompts, [_loginPrompt]);
  });

  test("removePrompt for an unknown id emits nothing", () async {
    tracker.addPrompt(prompt: _replacePrompt);
    final List<int> lengths = <int>[];
    final subscription = tracker.promptsStream.listen((prompts) => lengths.add(prompts.length));
    addTearDown(subscription.cancel);

    tracker.removePrompt(id: "missing");
    await pumpEventQueue();

    expect(lengths, [1]);
  });

  test("clear drops all pending prompts on helper disconnect", () {
    tracker.addPrompt(prompt: _replacePrompt);
    tracker.addPrompt(prompt: _loginPrompt);

    tracker.clear();

    expect(tracker.prompts, isEmpty);
  });

  test("writes after dispose are ignored instead of throwing", () {
    final BridgePromptTracker disposed = BridgePromptTracker()..dispose();

    expect(() => disposed.addPrompt(prompt: _replacePrompt), returnsNormally);
    expect(() => disposed.removePrompt(id: "p1"), returnsNormally);
    expect(disposed.clear, returnsNormally);
  });
}
