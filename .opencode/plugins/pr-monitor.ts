import { tool, type Plugin } from "@opencode-ai/plugin"
import { readFile } from "node:fs/promises"
import { join } from "node:path"

// ============================================================================
// pr-monitor — opencode plugin that watches GitHub PRs and reports changes.
//
// Design (settled via user interview; see .sisyphus/plans/pr-monitor-plugin.md):
// - One watch per PR, owned by the session that started it. Explicit
//   `owner/repo#123` or PR URL targets only — no cwd inference.
// - Polls GitHub via `gh api graphql` (one query per watch per tick).
// - Rolling debounce (no cap): any activity resets the quiet timer. When the
//   quiet window elapses, a report is generated fresh from the latest
//   snapshot and delivered to the owning session via promptAsync.
// - CI hold: a due report is held while the check suite is running, bounded
//   by maxCiWaitMinutes, then force-flushed naming unfinished checks.
// - Reports are facts only: no advice, no comment bodies — counts + authors.
//   "New" = created after this watch's lastFlushAt baseline.
// - Comments authored by the authenticated gh user containing the configured
//   ignore tag are invisible to the plugin entirely.
// - In-memory only: opencode restarts drop all watches by design.
// ============================================================================

// The opencode plugin loader invokes EVERY export of files in
// .opencode/plugins/ as a plugin, so `PrMonitorPlugin` must stay the sole export.

type Target = { owner: string; repo: string; number: number }

type MonitorConfig = {
  debounceMinutes: number
  maxCiWaitMinutes: number
  pollIntervalSeconds: number
  ignoreCommentTag: string | undefined
}

type CommentMeta = { author: string; isBot: boolean; createdAt: string }

type CheckInfo = { name: string; outcome: "pending" | "success" | "failure" }

type ReviewInfo = { login: string; state: string }

type PrSnapshot = {
  title: string
  url: string
  state: "OPEN" | "MERGED" | "CLOSED"
  mergeable: "MERGEABLE" | "CONFLICTING" | "UNKNOWN"
  headSha: string
  checks: CheckInfo[] // empty = PR has no CI checks
  reviews: ReviewInfo[] // latest review per reviewer (submitted only)
  pendingReviewers: string[] // requested, not yet reviewed
  unresolvedThreads: number
  inlineComments: CommentMeta[] // ignore-filtered
  issueCommentsTotal: number // totalCount minus ignored among fetched window
  issueComments: CommentMeta[] // ignore-filtered (last 100 fetched)
}

class PollError extends Error {
  readonly notFound: boolean
  constructor(message: string, opts?: { notFound?: boolean }) {
    super(message)
    this.notFound = opts?.notFound ?? false
  }
}


const SHORT_RE = /^([A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)\/([A-Za-z0-9._-]+)#(\d+)$/
const URL_RE = /^https:\/\/github\.com\/([A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)\/([A-Za-z0-9._-]+)\/pull\/(\d+)(?:[/?#].*)?$/

function parseTarget(input: string): Target | { error: string } {
  const trimmed = input.trim()
  const match = SHORT_RE.exec(trimmed) ?? URL_RE.exec(trimmed)
  if (!match) {
    return {
      error:
        `Invalid PR identifier: "${input}". Use "owner/repo#123" or a full PR URL ` +
        `(https://github.com/owner/repo/pull/123). The repo must always be explicit.`,
    }
  }
  return { owner: match[1]!, repo: match[2]!, number: Number(match[3]!) }
}

function targetKey(target: Target): string {
  return `${target.owner}/${target.repo}#${target.number}`
}


const CONFIG_FILE = "pr-monitor.json"

const DEFAULT_CONFIG: MonitorConfig = {
  debounceMinutes: 5,
  maxCiWaitMinutes: 30,
  pollIntervalSeconds: 60,
  ignoreCommentTag: undefined,
}

const MIN_POLL_INTERVAL_SECONDS = 30

function resolveConfig(raw: unknown): MonitorConfig {
  const cfg = { ...DEFAULT_CONFIG }
  if (typeof raw !== "object" || raw === null) return cfg
  const record = raw as Record<string, unknown>
  const num = (key: string): number | undefined => {
    const value = record[key]
    return typeof value === "number" && Number.isFinite(value) && value > 0 ? value : undefined
  }
  cfg.debounceMinutes = num("debounceMinutes") ?? cfg.debounceMinutes
  cfg.maxCiWaitMinutes = num("maxCiWaitMinutes") ?? cfg.maxCiWaitMinutes
  const poll = num("pollIntervalSeconds") ?? cfg.pollIntervalSeconds
  cfg.pollIntervalSeconds = Math.max(poll, MIN_POLL_INTERVAL_SECONDS)
  const tag = record["ignoreCommentTag"]
  cfg.ignoreCommentTag = typeof tag === "string" && tag.length > 0 ? tag : undefined
  return cfg
}

async function loadConfig(dirs: string[]): Promise<MonitorConfig> {
  for (const dir of dirs) {
    try {
      const text = await readFile(join(dir, ".opencode", CONFIG_FILE), "utf8")
      return resolveConfig(JSON.parse(text))
    } catch {
      // missing/unreadable/invalid file in this dir -> try next, else defaults
    }
  }
  return resolveConfig(undefined)
}


const PR_QUERY = `
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      title url state mergeable headRefOid
      commits(last: 1) { nodes { commit { statusCheckRollup {
        contexts(first: 100) { nodes {
          __typename
          ... on CheckRun { name status conclusion }
          ... on StatusContext { context state }
        } }
      } } } }
      reviewRequests(first: 50) { nodes { requestedReviewer {
        __typename
        ... on User { login }
        ... on Team { slug }
        ... on Bot { login }
      } } }
      latestReviews(first: 50) { nodes { author { login __typename } state } }
      reviewThreads(first: 100) { nodes {
        isResolved
        comments(first: 100) { nodes { author { login __typename } body createdAt } }
      } }
      comments(last: 100) { totalCount nodes { author { login __typename } body createdAt } }
    }
  }
}`

type RawComment = { author: { login: string; __typename: string } | null; body: string; createdAt: string }

function toMeta(raw: RawComment): CommentMeta {
  return {
    author: raw.author?.login ?? "ghost",
    isBot: raw.author?.__typename === "Bot",
    createdAt: raw.createdAt,
  }
}

function normalizeSnapshot(
  payload: unknown,
  opts: { ignoreTag: string | undefined; selfLogin: string | undefined },
): PrSnapshot {
  const pr = (payload as any)?.data?.repository?.pullRequest
  if (!pr) throw new PollError("PR not found in GraphQL response", { notFound: true })

  const ignored = (raw: RawComment): boolean =>
    opts.ignoreTag !== undefined &&
    opts.selfLogin !== undefined &&
    raw.author?.login === opts.selfLogin &&
    raw.body.includes(opts.ignoreTag)

  const checks: CheckInfo[] = []
  const contexts = pr.commits?.nodes?.[0]?.commit?.statusCheckRollup?.contexts?.nodes ?? []
  for (const ctx of contexts) {
    if (ctx.__typename === "CheckRun") {
      const outcome =
        ctx.status !== "COMPLETED"
          ? "pending"
          : ["SUCCESS", "NEUTRAL", "SKIPPED"].includes(ctx.conclusion)
            ? "success"
            : "failure"
      checks.push({ name: ctx.name, outcome })
    } else if (ctx.__typename === "StatusContext") {
      const outcome = ctx.state === "SUCCESS" ? "success" : ["PENDING", "EXPECTED"].includes(ctx.state) ? "pending" : "failure"
      checks.push({ name: ctx.context, outcome })
    }
  }

  const reviews: ReviewInfo[] = (pr.latestReviews?.nodes ?? [])
    .filter((node: any) => node.author?.login && node.state !== "PENDING")
    .map((node: any) => ({ login: node.author.login, state: node.state }))

  const pendingReviewers: string[] = (pr.reviewRequests?.nodes ?? [])
    .map((node: any) => node.requestedReviewer?.login ?? node.requestedReviewer?.slug)
    .filter((name: unknown): name is string => typeof name === "string")

  const threads = pr.reviewThreads?.nodes ?? []
  const inlineComments: CommentMeta[] = []
  for (const thread of threads) {
    for (const comment of thread.comments?.nodes ?? []) {
      if (!ignored(comment)) inlineComments.push(toMeta(comment))
    }
  }

  const issueNodes: RawComment[] = pr.comments?.nodes ?? []
  const issueVisible = issueNodes.filter((node) => !ignored(node))
  const ignoredCount = issueNodes.length - issueVisible.length

  return {
    title: pr.title,
    url: pr.url,
    state: pr.state,
    mergeable: pr.mergeable ?? "UNKNOWN",
    headSha: pr.headRefOid,
    checks,
    reviews,
    pendingReviewers,
    unresolvedThreads: threads.filter((thread: any) => !thread.isResolved).length,
    inlineComments,
    issueCommentsTotal: Math.max((pr.comments?.totalCount ?? issueNodes.length) - ignoredCount, 0),
    issueComments: issueVisible.map(toMeta),
  }
}

type CiPhase = "none" | "running" | "concluded"

function ciPhase(snapshot: PrSnapshot): CiPhase {
  if (snapshot.checks.length === 0) return "none"
  return snapshot.checks.some((check) => check.outcome === "pending") ? "running" : "concluded"
}


function commentSig(comments: CommentMeta[]): string {
  const last = comments[comments.length - 1]
  return `${comments.length}:${last?.createdAt ?? ""}`
}

function reviewSig(snapshot: PrSnapshot): string {
  const states = snapshot.reviews.map((review) => `${review.login}=${review.state}`).sort()
  const pending = [...snapshot.pendingReviewers].sort()
  return `${states.join(",")}|${pending.join(",")}`
}

function ciConcludedSig(snapshot: PrSnapshot): string {
  const failed = snapshot.checks
    .filter((check) => check.outcome === "failure")
    .map((check) => check.name)
    .sort()
  return `${snapshot.headSha}:${failed.join(",")}`
}

/** True when something report-worthy changed between consecutive polls. */
function detectActivity(prev: PrSnapshot, next: PrSnapshot): boolean {
  if (prev.state !== next.state) return true
  if (prev.mergeable !== next.mergeable) return true
  if (reviewSig(prev) !== reviewSig(next)) return true
  if (prev.unresolvedThreads !== next.unresolvedThreads) return true
  if (commentSig(prev.inlineComments) !== commentSig(next.inlineComments)) return true
  if (prev.issueCommentsTotal !== next.issueCommentsTotal || commentSig(prev.issueComments) !== commentSig(next.issueComments)) return true
  // CI: only suite conclusion counts. Transitions into "running" (new push)
  // and per-check progress are intentionally NOT activity.
  if (ciPhase(next) === "concluded" && (ciPhase(prev) !== "concluded" || ciConcludedSig(prev) !== ciConcludedSig(next))) return true
  return false
}


function authorBreakdown(comments: CommentMeta[]): string {
  const counts = new Map<string, number>()
  for (const comment of comments) {
    const name = comment.isBot ? `${comment.author}[bot]` : comment.author
    counts.set(name, (counts.get(name) ?? 0) + 1)
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([name, count]) => `${count} ${name}`)
    .join(", ")
}

function newSince(comments: CommentMeta[], baselineMs: number): CommentMeta[] {
  return comments.filter((comment) => Date.parse(comment.createdAt) > baselineMs)
}

function ciLine(snapshot: PrSnapshot, forcedHoldMinutes: number | undefined): string {
  const phase = ciPhase(snapshot)
  if (phase === "none") return "- CI: none"
  const total = snapshot.checks.length
  const failed = snapshot.checks.filter((check) => check.outcome === "failure")
  const pending = snapshot.checks.filter((check) => check.outcome === "pending")
  if (phase === "concluded") {
    if (failed.length === 0) return `- CI: passing (${total}/${total})`
    return `- CI: failing (${failed.length}/${total} failed: ${failed.map((check) => check.name).join(", ")})`
  }
  if (forcedHoldMinutes !== undefined) {
    return `- CI: running for ${forcedHoldMinutes}m+ (in_progress: ${pending.map((check) => check.name).join(", ")})`
  }
  const done = total - pending.length
  const failedPart = failed.length > 0 ? `, ${failed.length} failed so far: ${failed.map((check) => check.name).join(", ")}` : ""
  return `- CI: running (${done}/${total} done${failedPart})`
}

function reviewLine(snapshot: PrSnapshot): string {
  const MARKS: Record<string, string> = {
    APPROVED: "✓ approved",
    CHANGES_REQUESTED: "✗ changes_requested",
    COMMENTED: "✦ commented",
    DISMISSED: "⊘ dismissed",
  }
  const parts = snapshot.reviews.map((review) => `${review.login} ${MARKS[review.state] ?? review.state.toLowerCase()}`)
  for (const login of snapshot.pendingReviewers) parts.push(`${login} ⏳ pending`)
  return `- Reviews: ${parts.length > 0 ? parts.join(" · ") : "none"}`
}

function buildReport(
  target: Target,
  snapshot: PrSnapshot,
  opts: { baselineMs: number; forcedHoldMinutes?: number },
): string {
  const stateSuffix = snapshot.state !== "OPEN" ? ` — ${snapshot.state}` : ""
  const newInline = newSince(snapshot.inlineComments, opts.baselineMs)
  const newIssue = newSince(snapshot.issueComments, opts.baselineMs)
  const newPart = (fresh: CommentMeta[]): string =>
    fresh.length > 0 ? `${fresh.length} new since last flush: ${authorBreakdown(fresh)}` : "0 new since last flush"
  return [
    `[PR Monitor] ${targetKey(target)} — "${snapshot.title}"${stateSuffix} (${snapshot.url})`,
    ciLine(snapshot, opts.forcedHoldMinutes),
    `- Mergeable: ${snapshot.mergeable}`,
    reviewLine(snapshot),
    `- [comment:inline] ${snapshot.unresolvedThreads} unresolved threads (${newPart(newInline)})`,
    `- [comment:issue] ${snapshot.issueCommentsTotal} total (${newPart(newIssue)})`,
  ].join("\n")
}


type WatchDeps = {
  now: () => number
  fetchSnapshot: () => Promise<PrSnapshot>
  deliver: (report: string) => void
  log: (message: string) => void
  onStopped: () => void
}

const MAX_CONSECUTIVE_FAILURES = 10

class PrWatch {
  readonly target: Target
  readonly sessionID: string
  readonly config: MonitorConfig
  private readonly deps: WatchDeps
  private readonly startedAt: number

  private snapshot: PrSnapshot | undefined
  private dirty = false
  private lastActivityAt = 0
  private lastFlushAt: number
  private holdStartedAt: number | undefined
  private consecutiveFailures = 0
  private stopped = false
  private ticking = false

  constructor(input: { target: Target; sessionID: string; config: MonitorConfig; deps: WatchDeps; initial: PrSnapshot }) {
    this.target = input.target
    this.sessionID = input.sessionID
    this.config = input.config
    this.deps = input.deps
    this.startedAt = input.deps.now()
    this.lastFlushAt = this.startedAt
    this.snapshot = input.initial
  }

  get isStopped(): boolean {
    return this.stopped
  }

  statusLine(): string {
    const now = this.deps.now()
    const phase = this.holdStartedAt !== undefined ? "ci-hold" : "watching"
    const baselineAge = Math.round((now - this.lastFlushAt) / 60_000)
    const failures = this.consecutiveFailures > 0 ? `, ${this.consecutiveFailures} consecutive poll failures` : ""
    return `${targetKey(this.target)} — ${phase}, ${this.dirty ? "activity buffered" : "quiet"}, baseline ${baselineAge}m ago${failures}`
  }

  /** Periodic poll; never throws. */
  async tick(): Promise<void> {
    if (this.stopped || this.ticking) return
    this.ticking = true
    try {
      let next: PrSnapshot
      try {
        next = await this.deps.fetchSnapshot()
      } catch (error) {
        this.handlePollFailure(error)
        return
      }
      this.consecutiveFailures = 0
      if (this.snapshot !== undefined && detectActivity(this.snapshot, next)) {
        this.dirty = true
        this.lastActivityAt = this.deps.now()
        this.holdStartedAt = undefined
      }
      this.snapshot = next
      this.maybeAutoFlush()
    } finally {
      this.ticking = false
    }
  }

  /** Manual flush: always re-fetches and always returns a full report. */
  async manualFlush(): Promise<string> {
    try {
      this.snapshot = await this.deps.fetchSnapshot()
      this.consecutiveFailures = 0
    } catch (error) {
      if (this.snapshot === undefined) return `${targetKey(this.target)}: flush failed — ${(error as Error).message}`
      // fall through with last known snapshot, stated factually
      const report = this.flush(undefined)
      return `${report}\n(note: refresh failed — ${(error as Error).message}; data is from the previous poll)`
    }
    const report = this.flush(undefined)
    this.stopIfTerminal()
    return report
  }

  stop(): void {
    if (this.stopped) return
    this.stopped = true
    this.deps.onStopped()
  }

  private handlePollFailure(error: unknown): void {
    const message = error instanceof Error ? error.message : String(error)
    if (error instanceof PollError && error.notFound) {
      this.deps.deliver(`[PR Monitor] ${targetKey(this.target)} — monitor stopped: PR not found (deleted or inaccessible). Last error: ${message}`)
      this.stop()
      return
    }
    this.consecutiveFailures += 1
    this.deps.log(`poll failed for ${targetKey(this.target)} (${this.consecutiveFailures}/${MAX_CONSECUTIVE_FAILURES}): ${message}`)
    if (this.consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
      this.deps.deliver(`[PR Monitor] ${targetKey(this.target)} — monitor stopped: ${MAX_CONSECUTIVE_FAILURES} consecutive poll failures. Last error: ${message}`)
      this.stop()
    }
  }

  private maybeAutoFlush(): void {
    if (!this.dirty || this.snapshot === undefined) return
    const now = this.deps.now()
    if (now - this.lastActivityAt < this.config.debounceMinutes * 60_000) return

    let forcedHoldMinutes: number | undefined
    if (ciPhase(this.snapshot) === "running") {
      if (this.holdStartedAt === undefined) this.holdStartedAt = now
      const heldMs = now - this.holdStartedAt
      if (heldMs < this.config.maxCiWaitMinutes * 60_000) return
      forcedHoldMinutes = Math.round(heldMs / 60_000)
    }
    this.deps.deliver(this.flush(forcedHoldMinutes))
    this.stopIfTerminal()
  }

  private flush(forcedHoldMinutes: number | undefined): string {
    const snapshot = this.snapshot!
    const report = buildReport(this.target, snapshot, { baselineMs: this.lastFlushAt, forcedHoldMinutes })
    this.lastFlushAt = this.deps.now()
    this.dirty = false
    this.holdStartedAt = undefined
    return report
  }

  private stopIfTerminal(): void {
    if (this.snapshot !== undefined && this.snapshot.state !== "OPEN") this.stop()
  }
}


export const PrMonitorPlugin: Plugin = async ({ client, directory, worktree, $ }) => {
  type Entry = { watch: PrWatch; timer: ReturnType<typeof setInterval> }
  const watches = new Map<string, Entry>() // key: `${sessionID} ${owner/repo#n}`
  let selfLogin: string | undefined

  const log = (message: string): void => {
    void client.app.log({ body: { service: "pr-monitor", level: "info", message } }).catch(() => {})
  }

  const runGh = async (args: string[]): Promise<string> => {
    const result = await $`gh ${args}`.quiet().nothrow()
    if (result.exitCode !== 0) {
      const stderr = result.stderr.toString().trim()
      const notFound = /could not resolve|not found|404/i.test(stderr)
      throw new PollError(stderr || `gh exited with code ${result.exitCode}`, { notFound })
    }
    return result.stdout.toString()
  }

  const fetchSnapshot = async (target: Target, config: MonitorConfig): Promise<PrSnapshot> => {
    const stdout = await runGh([
      "api", "graphql",
      "-f", `query=${PR_QUERY}`,
      "-F", `owner=${target.owner}`,
      "-F", `repo=${target.repo}`,
      "-F", `number=${target.number}`,
    ])
    let payload: unknown
    try {
      payload = JSON.parse(stdout)
    } catch {
      throw new PollError("gh returned non-JSON output")
    }
    return normalizeSnapshot(payload, { ignoreTag: config.ignoreCommentTag, selfLogin })
  }

  const deliver = (sessionID: string) => (report: string) => {
    void client.session
      .promptAsync({ path: { id: sessionID }, body: { parts: [{ type: "text", text: report }] } })
      .catch((error: unknown) => log(`failed to deliver report to session ${sessionID}: ${error}`))
  }

  const sessionWatches = (sessionID: string): PrWatch[] =>
    [...watches.values()].filter((entry) => entry.watch.sessionID === sessionID).map((entry) => entry.watch)

  const selectWatches = (sessionID: string, pr: string): PrWatch[] | { error: string } => {
    if (pr === "all") return sessionWatches(sessionID)
    const target = parseTarget(pr)
    if ("error" in target) return target
    const entry = watches.get(`${sessionID} ${targetKey(target)}`)
    if (!entry) return { error: `No monitor for ${targetKey(target)} in this session. Use action "status" to list active monitors.` }
    return [entry.watch]
  }

  const startWatch = async (sessionID: string, pr: string): Promise<string> => {
    const target = parseTarget(pr)
    if ("error" in target) return target.error
    const key = `${sessionID} ${targetKey(target)}`
    const existing = watches.get(key)
    if (existing) return `Already monitoring ${targetKey(target)} in this session.\n${existing.watch.statusLine()}`

    const config = await loadConfig([directory, worktree])
    if (config.ignoreCommentTag !== undefined && selfLogin === undefined) {
      try {
        selfLogin = (await runGh(["api", "user", "--jq", ".login"])).trim()
      } catch (error) {
        return `Cannot start monitor: ignoreCommentTag is configured but resolving the authenticated gh user failed (${(error as Error).message}). Run \`gh auth status\` to check.`
      }
    }

    let initial: PrSnapshot
    try {
      initial = await fetchSnapshot(target, config)
    } catch (error) {
      return `Cannot start monitor for ${targetKey(target)}: ${(error as Error).message}`
    }
    if (initial.state !== "OPEN") return `Cannot start monitor: ${targetKey(target)} is already ${initial.state}.`

    const watch = new PrWatch({
      target,
      sessionID,
      config,
      initial,
      deps: {
        now: Date.now,
        fetchSnapshot: () => fetchSnapshot(target, config),
        deliver: deliver(sessionID),
        log,
        onStopped: () => {
          const entry = watches.get(key)
          if (entry) clearInterval(entry.timer)
          watches.delete(key)
        },
      },
    })
    const timer = setInterval(() => void watch.tick(), config.pollIntervalSeconds * 1000)
    watches.set(key, { watch, timer })
    log(`started monitoring ${targetKey(target)} for session ${sessionID}`)
    return (
      `Started monitoring ${targetKey(target)} — "${initial.title}".\n` +
      `Polling every ${config.pollIntervalSeconds}s; reports arrive in this session as [PR Monitor] messages after ` +
      `${config.debounceMinutes} quiet minutes following detected activity. The monitor stops automatically when the PR ` +
      `is merged or closed, and does not survive an opencode restart.`
    )
  }

  return {
    tool: {
      pr_monitor: tool({
        description:
          "Monitor a GitHub PR in the background. Detects CI suite conclusions, new reviews, new inline/issue comments, " +
          "mergeability changes, and merge/close. Changes are aggregated (rolling debounce) and delivered to THIS session " +
          "as a '[PR Monitor]' message stating facts only. Actions: start (begin watching a PR), stop (end watching), " +
          "flush (immediately return a full status report and reset the 'new since' baseline — do this after handling a " +
          "report), status (list this session's monitors). The pr argument must be explicit 'owner/repo#123' or a full " +
          "PR URL; 'all' is allowed for stop/flush. Tuning lives in .opencode/pr-monitor.json. Monitors are per-session " +
          "and do not survive opencode restarts.",
        args: {
          action: tool.schema.enum(["start", "stop", "flush", "status"]).describe("What to do"),
          pr: tool.schema
            .string()
            .optional()
            .describe("PR identifier: 'owner/repo#123' or PR URL. Required for start/stop/flush; 'all' allowed for stop/flush."),
        },
        async execute(args, context) {
          const sessionID = context.sessionID
          switch (args.action) {
            case "start": {
              if (!args.pr || args.pr === "all") return "action 'start' requires a single explicit pr: 'owner/repo#123' or a PR URL."
              return await startWatch(sessionID, args.pr)
            }
            case "stop": {
              if (!args.pr) return "action 'stop' requires pr: 'owner/repo#123', a PR URL, or 'all'."
              const selected = selectWatches(sessionID, args.pr)
              if ("error" in selected) return selected.error
              if (selected.length === 0) return "No active monitors in this session."
              for (const watch of selected) watch.stop()
              return `Stopped ${selected.length} monitor(s): ${selected.map((watch) => targetKey(watch.target)).join(", ")}.`
            }
            case "flush": {
              if (!args.pr) return "action 'flush' requires pr: 'owner/repo#123', a PR URL, or 'all'."
              const selected = selectWatches(sessionID, args.pr)
              if ("error" in selected) return selected.error
              if (selected.length === 0) return "No active monitors in this session."
              const reports = await Promise.all(selected.map((watch) => watch.manualFlush()))
              return reports.join("\n\n")
            }
            case "status": {
              const active = sessionWatches(sessionID)
              if (active.length === 0) return "No active monitors in this session."
              return active.map((watch) => watch.statusLine()).join("\n")
            }
          }
        },
      }),
    },

    event: async ({ event }) => {
      if (event.type !== "session.deleted") return
      const sessionID = (event.properties as { info?: { id?: string } })?.info?.id
      if (!sessionID) return
      for (const entry of [...watches.values()]) {
        if (entry.watch.sessionID === sessionID) entry.watch.stop()
      }
    },

    dispose: async () => {
      for (const entry of [...watches.values()]) entry.watch.stop()
    },
  }
}
