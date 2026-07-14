# Session Pull Request Monitoring: Considerations

> **Non-authoritative.** Durable decisions live in `PLAN.md`; mutable execution
> state lives in `TRACKER.md`. This file records rejected alternatives and
> migration context only.

## Rejected Alternatives

### Keep the legacy single-file plan

Rejected because it duplicated durable intent, mutable tracking, stage goals,
and PR implementation detail in one document. The canonical `.plan` tree gives
each concern one owner and supports strict wave baselines.

### Interleave with parallel-plugin implementation

Rejected because both plans change Drift session fields, `SessionRepository`,
`SessionMutationDispatcher`, archive persistence, and event composition. Even
if schema numbers were dynamically allocated, alternating PRs would repeatedly
invalidate file/class assumptions. This plan completes first; parallel plugins
then receive explicit stale-plan re-review.

### Nullable `pullRequestHistory`

Rejected because legacy omission has one honest display meaning: the old bridge
provides no history beyond its existing headline. `@Default([])` keeps modern
state non-null and avoids a compatibility branch beyond the wire boundary.

### Unbounded GraphQL pagination

Rejected for this scope. `gh pr list` already provides the exact typed fields
needed and accepts a finite limit. Fetching 1,001 rows supports the newest 1,000,
makes truncation observable, and prevents destructive replacement from an
incomplete result without adding a second GitHub query subsystem.

### Periodic git polling

Rejected because git `HEAD` is locally stream-observable. The design watches the
resolved `HEAD` parent and uses retry-with-backoff only to recover a failed watch
setup; it does not repeatedly invoke git to rediscover data already exposed by
filesystem events.

### Reuse session-view declarations for project presence

Rejected because session viewing marks content seen and deliberately delays
resume/reconnect reassertion until fresh content renders. Project presence has no
seen side effect and must reassert immediately while foregrounded. Separate
contracts/services preserve both invariants.

### Read archived PRs from the global cache

Rejected because another live session or a local `gh auth switch` could mutate
archived presentation. A terminal owner-scoped snapshot is the smallest design
that makes archive immutable and account-safe.

### Put GitHub behavior behind `BridgePluginApi`

Rejected because PR association is derived from the bridge's local git checkout
and local `gh` credentials, not from an assistant backend. Plugin exposure would
leak forge/session-shell concerns across the sacred plugin boundary.
