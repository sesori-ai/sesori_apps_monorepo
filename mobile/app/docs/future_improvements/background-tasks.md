# Background Tasks - Future Improvements

## Smart Completed Task Visibility

**Status**: Planned

### Problem
When expanding the completed tasks section, all historically completed tasks are shown. After many tasks accumulate, this becomes noisy. The user typically only cares about tasks that completed since they last checked.

### Proposed Behavior
- Track locally the timestamp of when the user last opened/viewed the completed tasks section (the "Show N completed" toggle).
- On next expand, only show tasks completed **since that last-viewed timestamp** by default.
- Older completed tasks are hidden behind a secondary "Show N older tasks" button.
- The last-viewed timestamp must persist across app restarts (use local storage / shared_preferences).

### Implementation Notes
- Store per-session `lastViewedCompletedAt` timestamp (keyed by session ID).
- Compare against `session.time.updated` on each completed child to determine new vs old.
- Update the stored timestamp each time the user taps "Show completed".
- Consider cleanup of stale entries (sessions the user hasn't visited in X days).
