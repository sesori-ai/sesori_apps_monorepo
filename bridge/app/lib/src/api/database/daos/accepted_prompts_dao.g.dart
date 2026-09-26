// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accepted_prompts_dao.dart';

// ignore_for_file: type=lint
mixin _$AcceptedPromptsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AcceptedPromptsTableTable get acceptedPromptsTable =>
      attachedDatabase.acceptedPromptsTable;
  AcceptedPromptsDaoManager get managers => AcceptedPromptsDaoManager(this);
}

class AcceptedPromptsDaoManager {
  final _$AcceptedPromptsDaoMixin _db;
  AcceptedPromptsDaoManager(this._db);
  $$AcceptedPromptsTableTableTableManager get acceptedPromptsTable =>
      $$AcceptedPromptsTableTableTableManager(
        _db.attachedDatabase,
        _db.acceptedPromptsTable,
      );
}
