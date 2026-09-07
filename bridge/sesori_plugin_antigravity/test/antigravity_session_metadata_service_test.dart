import "dart:convert";
import "dart:io";

import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

const _id = "aabbccdd-1234-4567-8123-123456789abc";
const _otherId = "11111111-2222-3333-4444-555555555555";

class _DuplicateRepository({required super.storage}) extends AntigravitySessionMetadataRepository {
  @override
  Future<({List<String> paths, bool truncated})> listPaths({
    required String geminiHome,
    required int maxEntries,
  }) async => (paths: ["first", "duplicate"], truncated: true);

  @override
  Future<AntigravitySessionMetadata> read({required String path, required int maxBytes}) async =>
      AntigravitySessionMetadata(sessionId: _id, directory: p.absolute(path));
}

void main() {
  late Directory home;
  late Directory conversations;
  const storage = AntigravitySessionMetadataStorage();
  late AntigravitySessionMetadataRepository repository;
  late AntigravitySessionMetadataService service;

  setUp(() async {
    home = await Directory.systemTemp.createTemp("antigravity-metadata-");
    conversations = Directory(p.join(home.path, "antigravity-acp", "conversations"));
    repository = AntigravitySessionMetadataRepository(storage: storage);
    service = AntigravitySessionMetadataService(repository: repository);
  });
  tearDown(() => home.delete(recursive: true));

  Future<File> write({required String name, required String content}) async {
    await conversations.create(recursive: true);
    return await File(p.join(conversations.path, name)).writeAsString(content);
  }

  test("missing history is inert and creates no profile directories", () async {
    expect((await service.recover(geminiHome: home.path)).directories, isEmpty);
    expect(conversations.existsSync(), isFalse);
  });

  test("isolated metadata yields canonical UUID/cwd without opening other history files", () async {
    final cwd = p.join(home.path, "repo");
    final file = await write(name: "${_id.toUpperCase()}.meta", content: jsonEncode({"cwd": "$cwd/child/.."}));
    await write(name: "history.sqlite", content: "not JSON");
    await write(name: "oauth_token.json", content: "not JSON");
    await Directory(p.join(conversations.path, "brain.meta")).create();
    final before = await file.readAsString();
    final candidate = await repository.read(path: file.path, maxBytes: 1024);
    expect(candidate.sessionId, _id);
    expect(candidate.directory, cwd);
    final result = await service.recover(geminiHome: home.path);
    expect(result.directories, {_id: cwd});
    expect(result.directories.clear, throwsUnsupportedError);
    expect(await file.readAsString(), before);
  });

  test("malformed JSON/cwd/UUID, relative cwd and oversized files cannot poison valid recovery", () async {
    await write(name: "$_id.meta", content: jsonEncode({"cwd": home.path}));
    await write(name: "$_otherId.meta", content: '{"cwd":"../relative"}');
    await write(name: "not-a-uuid.meta", content: jsonEncode({"cwd": home.path}));
    await write(name: "bad-json.meta", content: "{broken");
    await write(name: "bad-cwd.meta", content: '{"cwd":123}');
    await write(name: "large.meta", content: "x" * (AntigravitySessionMetadataService.maxFileBytes + 1));
    expect((await service.recover(geminiHome: home.path)).directories, {_id: home.path});
    final candidate = await repository.read(path: p.join(conversations.path, "$_otherId.meta"), maxBytes: 1024);
    expect(p.isAbsolute(candidate.directory), isFalse, reason: "Never fabricate a cwd from the bridge process");
  });

  test("decoder diagnostics retain type/location but never render ignored payload values", () async {
    const secret = "synthetic-content-do-not-log";
    final file = await write(name: "$_id.meta", content: '{"ignored":"$secret","cwd":[]}');
    await expectLater(
      storage.read(path: file.path, maxBytes: 1024),
      throwsA(
        isA<Exception>()
            .having((error) => error.toString(), "field", contains("cwd"))
            .having((error) => error.toString(), "privacy", isNot(contains(secret))),
      ),
    );
  });

  test("listing counts all directory entries and reading bounds bytes before decoding", () async {
    for (var i = 0; i < 4; i++) {
      await write(name: "$i.sqlite", content: "unused");
    }
    final listing = await storage.listPaths(geminiHome: home.path, maxEntries: 2);
    expect(listing.truncated, isTrue);
    expect(listing.paths, isEmpty);
    final file = await write(name: "$_id.meta", content: "x" * 101);
    await expectLater(storage.read(path: file.path, maxBytes: 100), throwsFormatException);
  });

  test("listed symlinks are not followed", () async {
    final outside = await File(p.join(home.path, "outside")).writeAsString(jsonEncode({"cwd": home.path}));
    await conversations.create(recursive: true);
    await Link(p.join(conversations.path, "$_id.meta")).create(outside.path);
    expect((await service.recover(geminiHome: home.path)).directories, isEmpty);
  }, skip: Platform.isWindows ? "Creating Windows symlinks requires host privileges" : false);

  test("duplicate UUIDs retain the first normalized directory in one immutable batch", () async {
    final duplicateService = AntigravitySessionMetadataService(repository: _DuplicateRepository(storage: storage));
    expect((await duplicateService.recover(geminiHome: home.path)).directories, {_id: p.absolute("first")});
  });
}
