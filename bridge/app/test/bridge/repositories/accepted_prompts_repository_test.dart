import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/accepted_prompts_dao.dart";
import "package:sesori_bridge/src/repositories/accepted_prompts_repository.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  test("remembers accepted prompt ids per session until the retention window passes", () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final repository = AcceptedPromptsRepository(dao: AcceptedPromptsDao(database: database));
    final start = DateTime.utc(2026, 9);

    await withClock(Clock.fixed(start), () => repository.recordAccepted(sessionId: "s1", promptId: "old"));
    await withClock(
      Clock.fixed(start.add(const Duration(days: 29))),
      () => repository.recordAccepted(sessionId: "s1", promptId: "recent"),
    );
    expect(await repository.isAccepted(sessionId: "s1", promptId: "old"), isTrue);
    expect(await repository.isAccepted(sessionId: "s2", promptId: "old"), isFalse);

    await withClock(
      Clock.fixed(start.add(const Duration(days: 31))),
      () => repository.recordAccepted(sessionId: "s2", promptId: "new"),
    );
    expect(await repository.isAccepted(sessionId: "s1", promptId: "old"), isFalse);
    expect(await repository.isAccepted(sessionId: "s1", promptId: "recent"), isTrue);
    expect(await repository.isAccepted(sessionId: "s2", promptId: "new"), isTrue);
  });
}
