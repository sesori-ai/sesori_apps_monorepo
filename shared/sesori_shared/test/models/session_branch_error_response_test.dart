import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("a branch refusal round-trips and an unrecognized code decodes as unknown", () {
    const refusal = SessionBranchErrorResponse(
      code: SessionBranchErrorCode.branchPointUnavailable,
      message: "This message was compacted.",
    );

    expect(SessionBranchErrorResponse.fromJson(refusal.toJson()), refusal);
    expect(
      SessionBranchErrorResponse.fromJson(const {"code": "futureCode", "message": null}).code,
      SessionBranchErrorCode.unknown,
    );
  });
}
