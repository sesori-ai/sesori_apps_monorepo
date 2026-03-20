# Changelog

## [v0.2.0] - 2026-03-15

### Added
- Bridge mapper layer for HTTP traffic transformation (#2)
- SSE event buffering with replay on reconnect (#3)
- Project and session merging mappers (#4)
- Yaak API definitions for OpenCode

### Fixed
- Enable WebSocket ping for dead connection detection (#5)
- Exclude global project's worktree from virtual project list (#6)
- Updated CI workflows

### Changed
- Bump sesori_shared to ^0.1.1 and use shared auth models (#1)

## [v0.1.0] - 2026-03-13

### Added
- Full migration from Go bridge to pure Dart with complete feature parity
- Shared crypto and protocol package (`sesori_shared`) for code reuse with Flutter mobile app
- Windows support (new — Go bridge only supported macOS and Linux)
- npm distribution via `@sesori/bridge` with platform-specific binary packages
- 33 unit tests covering crypto, protocol, proxy, SSE, key exchange, and framing
