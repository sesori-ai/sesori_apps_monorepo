import "package:sesori_dart_core/src/services/session_approval_calculator.dart";
import "package:sesori_dart_core/src/testing/test_helpers.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _calculator = SessionApprovalCalculator();
const _ask = SessionApprovalMode.ask;
const _yolo = SessionApprovalMode.yolo;

Session _session({required String? parentId, required SessionApprovalMode? approvalOverride}) =>
    testSession(parentID: parentId).copyWith(approvalOverride: approvalOverride);

SessionApprovalMode? _sent({
  required String? parentId,
  required SessionApprovalMode? stored,
  required SessionApprovalMode bridgeDefault,
  required SessionApprovalMode pick,
}) {
  final session = _session(parentId: parentId, approvalOverride: stored);
  final control = SessionApprovalPerSession(effective: stored ?? bridgeDefault, bridgeDefault: bridgeDefault);
  final change = _calculator.change(session: session, control: control, mode: pick);
  expect(change, isNotNull, reason: "expected a change to send");
  return change?.approvalOverride;
}

void main() {
  group("control", () {
    test("an older bridge hides the control while YOLO is off", () {
      expect(
        _calculator.control(
          bridge: const YoloSettingsResponse(enabled: false),
          session: _session(parentId: null, approvalOverride: null),
        ),
        isA<SessionApprovalHidden>(),
      );
    });

    test("an older bridge shows bridge-wide YOLO while it is on", () {
      expect(
        _calculator.control(
          bridge: const YoloSettingsResponse(enabled: true),
          session: _session(parentId: null, approvalOverride: null),
        ),
        isA<SessionApprovalBridgeWideYolo>(),
      );
    });

    test("a supporting bridge applies the session override over its default", () {
      expect(
        _calculator.control(
          bridge: const YoloSettingsResponse(enabled: false, supportsSessionOverride: true),
          session: _session(parentId: null, approvalOverride: _yolo),
        ),
        isA<SessionApprovalPerSession>()
            .having((c) => c.effective, "effective", _yolo)
            .having((c) => c.bridgeDefault, "bridgeDefault", _ask),
      );
    });
  });

  group("change", () {
    test("a top-level pick of the other mode stores it", () {
      expect(_sent(parentId: null, stored: null, bridgeDefault: _ask, pick: _yolo), _yolo);
    });

    test("a top-level pick of the default clears the override", () {
      expect(_sent(parentId: null, stored: _ask, bridgeDefault: _yolo, pick: _yolo), isNull);
    });

    test("a top-level explicit override that matches the default still clears", () {
      expect(_sent(parentId: null, stored: _yolo, bridgeDefault: _yolo, pick: _yolo), isNull);
    });

    test("a child pick of the default stays explicit", () {
      expect(_sent(parentId: "parent-1", stored: null, bridgeDefault: _ask, pick: _ask), _ask);
    });

    test("a child pick of the other mode stores it", () {
      expect(_sent(parentId: "parent-1", stored: null, bridgeDefault: _ask, pick: _yolo), _yolo);
    });

    test("picking what the session already stores sends nothing", () {
      for (final (parentId, stored, bridgeDefault, pick) in [
        (null, null, _yolo, _yolo),
        (null, _ask, _yolo, _ask),
        ("parent-1", _yolo, _ask, _yolo),
      ]) {
        final session = _session(parentId: parentId, approvalOverride: stored);
        final control = SessionApprovalPerSession(effective: stored ?? bridgeDefault, bridgeDefault: bridgeDefault);
        expect(_calculator.change(session: session, control: control, mode: pick), isNull);
      }
    });
  });
}
