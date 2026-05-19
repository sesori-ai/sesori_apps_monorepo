# Changelog

## [Unreleased]

### App

- No changes

### Bridge

- No changes

## [1.0.7] - 2026-05-19

### App

#### Added
- OAuth flow overhaul with backend callback and long polling (#161)
- Persist agent, model & variant selection (#172)

#### Fixed
- Buffer SSE events during SessionDetailCubit loading to prevent race condition (#170)

### Bridge

#### Added
- OAuth flow overhaul with backend callback and long polling (#161)
- Persist agent, model & variant selection (#172)

#### Changed
- Minor log cleanup

## [1.0.6] - 2026-05-13

### App

#### Added
- Native Apple Sign-In support for iOS (#157)

#### Changed
- Added Fastlane and CI workflows for iOS/Android deploys (#158)

### Bridge

- No changes

## [1.0.5] - 2026-05-11

### App

- Initial tracked release.

### Bridge

- No changes

## [0.7.0] - 2026-05-17

### App

- No changes

### Bridge

#### Fixed
- Manage OpenCode and Bridge lifecycle conflicts with robust process identity tracking, singleton enforcement, and graceful shutdown coordination (#162)
- Handle OpenCode v1.14.48 schema changes and missing SSE event types (#159)

#### Changed
- Update Flutter to 3.41.9 (#143)

## [0.6.1] - 2026-04-29

### App

- No changes

### Bridge

#### Fixed
- Remove hardened runtime from macOS signing and strip xattrs on all install paths (#141)

## [0.6.0] - 2026-04-29

### App

- No changes

### Bridge

#### Added
- Google OAuth and email/password login support with PKCE flow (#137)
- `AuthProvider` enum to track last used authentication provider
- Comprehensive auth test coverage for login, profile, token validation, and token management
- Mobile login UI with provider selection buttons and email login form
- Migrated install paths to `~/.local/share/sesori` for XDG compliance (#138)
- Automatic symlink creation at `~/.local/bin/sesori-bridge` for immediate PATH access
- Updated shell and PowerShell installers to use XDG-compliant directories

#### Changed
- Config directory moved from `~/.config/sesori-bridge` to `~/.local/share/sesori`
- Token persistence now includes `lastProvider` field for multi-provider auth tracking
- Updated all documentation (README, INSTALL, RELEASING) with new install paths

## [0.5.0] - 2026-04-27

### App

- No changes

### Bridge

#### Added
- OS sleep prevention with configurable settings file (#131)
- Session effort selection support across mobile and bridge (#125)
- Inline chat error display in session detail (#126)
- OpenCode notification when deleting workspace from Sesori (#134)
- Improved wake lock lid-close behavior with laptop device-type warnings (#132)

#### Fixed
- Pass `roots=true` to OpenCode `/session` API to prevent child sessions from crowding out root sessions (#135)
- Model-aware variant recomputation in agent picker (#128)
- Recognize `command.executed` SSE frames instead of dropping them (#124)

#### Changed
- Updated Yaak API definitions

## [0.4.1] - 2026-04-22

### App

- No changes

### Bridge

#### Added
- macOS release binaries are now signed with a Developer ID Application certificate
- Bridge release documentation (`RELEASING.md`) for verification and manual test flow

#### Changed
- Updated npm wrapper tests to align with release workflow changes

## [0.4.0] - 2026-04-22

### App

- No changes

### Bridge

#### Added
- Native bootstrap support for `npx @sesori/bridge` to fetch and run binaries directly from GitHub release assets
- Detailed telemetry and logging for bridge push notification maintenance cycles
- Session event enrichment layer to provide additional context in bridge-to-phone event streams

#### Fixed
- OpenCode plugin now correctly recognizes and displays `alpha` and `beta` model statuses
- Stabilization of push notification state tracking with automatic pruning of stale session data
- Reliable session list refreshing on mobile devices after creating or archiving sessions through the bridge
- Improved error recovery and state synchronization in the bridge orchestrator

#### Changed
- Major internal refactoring of the bridge core to follow the "Aristotle" layered architecture (Foundation, API, Repository, Service)
- Improved session lifecycle management by extracting focused services for creation, archiving, and aborting operations

## [0.3.x] - 2026-04-15

### App

- No changes

### Bridge

- Any patch version change is done only as an attempt of fixing the release workflow and does not contain actual changes for the bridge code.

## [0.3.0] - 2026-04-15

### App

- No changes

### Bridge

#### Added
- Tagged bridge release pipeline with packaged multi-platform builds, checksums, and installer/bootstrap support
- Managed-install self-updates at startup and during long-running bridge sessions
- Bridge-managed worktrees, branch selection, and session diff APIs for OpenCode sessions
- Session metadata generation, including AI-assisted session naming and richer session lifecycle handling
- Permission reply flows for pending prompts, plus better session and project management endpoints

#### Fixed
- Prefer the newest available local or remote base branch when creating worktrees
- Protect shared-worktree sessions from unsafe cleanup paths
- Improve push notification accuracy for child sessions, aborted sessions, and awaiting-input states
- Improve OpenCode compatibility and bridge session-status recovery behavior

#### Changed
- Delay session creation until the first prompt instead of creating sessions immediately
- Shift notifications toward state-based updates instead of per-message noise

## [0.2.0] - 2026-03-15

### App

- No changes

### Bridge

#### Added
- Bridge mapper layer for HTTP traffic transformation (#2)
- SSE event buffering with replay on reconnect (#3)
- Project and session merging mappers (#4)
- Yaak API definitions for OpenCode

#### Fixed
- Enable WebSocket ping for dead connection detection (#5)
- Exclude global project's worktree from virtual project list (#6)
- Updated CI workflows

#### Changed
- Bump sesori_shared to ^0.1.1 and use shared auth models (#1)

## [0.1.0] - 2026-03-13

### App

- No changes

### Bridge

#### Added
- Full migration from Go bridge to pure Dart with complete feature parity
- Shared crypto and protocol package (`sesori_shared`) for code reuse with Flutter mobile app
- Windows support (new — Go bridge only supported macOS and Linux)
- npm distribution via `@sesori/bridge` with platform-specific binary packages
- 33 unit tests covering crypto, protocol, proxy, SSE, key exchange, and framing
