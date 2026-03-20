## 0.3.0

- **Breaking:** Updated `ProviderListResponse`

## 0.2.2

- Added more shared concurrency classes and utils

## 0.2.1

- Fixed some lints
- Added future extensions

## 0.2.0

- **Breaking:** Renamed `SseEventData` → `SesoriSseEvent`, `SseSessionEventData` → `SesoriSessionEvent`, and all `Sse*` variant types to `Sesori*`
- **Breaking:** Moved models from `models/opencode/` to `models/sesori/` (import paths changed)
- Added `SesoriSseEvent.projectsSummary` variant with `ProjectActivitySummary` model for bridge-originated project activity events
- JSON wire format unchanged — all `@FreezedUnionValue` strings preserved

## 0.1.3

- Added `GlobalSession` model for `/experimental/session` responses (Session + embedded project info)
- Added `SessionProject` model for lightweight project references within `GlobalSession`

## 0.1.2

- **Breaking:** `AgentInfo.mode` changed from `String` to `AgentMode` enum (`all`, `primary`, `subagent`, `unknown`)
- Enabled `toJson` on all OpenCode models (Project, Session, Message, etc.)

## 0.1.1

- Added API response and SSE event model types (Session, Message, MessagePart, SseEventData, Project, Auth models, etc.)

## 0.1.0

- Initial release
