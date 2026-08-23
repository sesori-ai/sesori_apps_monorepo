# Step 38 — sheets, dialogs, and status widgets

## Re-verification

- Rename project/session sheets and delete/archive confirmation sheets remained
  behavior-equivalent enough to share their stateful shells.
- Only three identical Prego two-action footers remained, not seven. Material
  dialog actions and vertically stacked authentication actions retain their
  distinct chrome.
- Only command picker, model picker, and prompt editor use the same helper-backed
  body sizing. Add Project, Reasoning, Question, and Permission own dynamic
  titles, safe-area policy, or route behavior and remain direct sheets.
- Three planned status-icon switches consume different state types and assign
  different meanings to `null`; a shared visual enum would add mappings without
  removing domain decisions, so they remain local.
- Agent and retry rows differ in expansion, truncation, color, and content. The
  small common `Row` shape did not justify another parameter-only widget.

## Changes

- Added app-local `RenameSheet` and `RemoteFailureView`; project/session wrappers
  retain domain calls and localized copy.
- Consolidated archive/delete confirmation content into
  `_CleanupConfirmSheet` while preserving destructive styling and worktree
  cleanup defaults.
- Added `PregoSheetActions`, `PregoGroupedNoticeRow`, and bounded body sizing to
  `showPregoBottomSheet`; migrated only exact matching consumers.
- Consolidated question option chrome in private `_ChoiceTile`, retaining each
  choice's semantics, focus behavior, keys, styling, and content.
- Replaced the authentication challenge boolean record with exhaustive switches
  over the sealed presentation variants.
- Updated the three required regression documents with dialog/sheet behavior.

## Behavior impact

Refactor-only. Rename, archive/delete confirmation, picker/editor sizing,
settings actions/notices, remote failure retry, question choices, and
authentication challenge behavior remain unchanged. No database, persistence,
wire, localization, analytics, or generated-model impact.

## Change budget

Totals exclude this evidence file and use `origin/main`:

| Scope | Files | Additions | Deletions |
| --- | ---: | ---: | ---: |
| Production/lib | 20 | 434 | 678 |
| Tests | 2 | 152 | 0 |
| Regression docs | 3 | 9 | 0 |

Net production change: **-244 lines**. There is no new dependency, DI
registration, persisted state, compatibility path, or generated source.

## Verification

- `flutter analyze --fatal-infos` (`client/module_prego`) — pass.
- `flutter test` (`client/module_prego`) — pass, 220 tests.
- `flutter analyze --fatal-infos` (`client/app`) — pass.
- `flutter test test/features/session_list test/features/project_list test/features/settings test/features/session_detail`
  (`client/app`) — pass, 480 tests.
- Post-review focused sheet tests — pass, 15 tests.
- `git diff --check` — pass.

Architecture implementation review approved the package boundaries and shared
APIs after `PregoGroupedNoticeRow` moved to `module_prego` and bounded sheet
height was clamped to the available body space.

A separate correctness review's exhausted-keyboard finding was fixed by flooring
available body space at zero. Its alternative 70%-height formula was not applied:
the migrated sheets already subtract the keyboard from 70% of the full viewport,
and this refactor deliberately preserves that behavior.
