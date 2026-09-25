import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  Map<String, dynamic> sessionJson({required Map<String, dynamic> extra}) => {
    "id": "ses_1",
    "projectID": "proj_1",
    "directory": "/tmp",
    "parentID": null,
    "title": null,
    "time": null,
    "pullRequest": null,
    ...extra,
  };

  group("Session.approvalOverride", () {
    test("an older bridge's missing field follows the bridge setting", () {
      expect(Session.fromJson(sessionJson(extra: const {})).approvalOverride, isNull);
    });

    test("round trips each mode", () {
      for (final mode in SessionApprovalMode.values) {
        final session = Session.fromJson(sessionJson(extra: {"approvalOverride": mode.name}));

        expect(session.approvalOverride, mode);
        expect(Session.fromJson(session.toJson()), session);
      }
    });

    test("a mode from a newer bridge reads as following the bridge setting", () {
      expect(Session.fromJson(sessionJson(extra: const {"approvalOverride": "later"})).approvalOverride, isNull);
    });
  });

  group("SetSessionApprovalOverrideRequest", () {
    test("round trips a mode", () {
      const request = SetSessionApprovalOverrideRequest(sessionId: "ses_1", approvalOverride: SessionApprovalMode.yolo);

      expect(request.toJson(), {"sessionId": "ses_1", "approvalOverride": "yolo"});
      expect(SetSessionApprovalOverrideRequest.fromJson(request.toJson()), request);
    });

    test("a missing override clears it", () {
      expect(
        SetSessionApprovalOverrideRequest.fromJson(const {"sessionId": "ses_1"}),
        const SetSessionApprovalOverrideRequest(sessionId: "ses_1", approvalOverride: null),
      );
    });
  });

  test("SessionApprovalOverrideErrorResponse reads an unknown code as unknown", () {
    expect(
      SessionApprovalOverrideErrorResponse.fromJson(const {"code": "sessionNotFound"}).code,
      SessionApprovalOverrideErrorCode.sessionNotFound,
    );
    expect(
      SessionApprovalOverrideErrorResponse.fromJson(const {"code": "later"}).code,
      SessionApprovalOverrideErrorCode.unknown,
    );
  });
}
