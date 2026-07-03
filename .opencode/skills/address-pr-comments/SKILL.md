---
name: address-pr-comments
description: Address unresolved inline PR review comments on a GitHub pull request. Fetches unresolved comments, assesses validity (with extra scrutiny for AI/bot reviewers), implements fixes, leaves a reply on every comment thread, and commits changes. Use when the user asks to address PR comments, resolve review feedback, implement requested changes, or handle PR review threads.
---

# address-pr-comments

Addresses unresolved inline PR review comments by assessing their validity, implementing fixes, and leaving a reply on each comment thread. Every thread gets a response — either confirming the fix or explaining why the comment was not addressed. Threads whose fix has been implemented and pushed are then **resolved** by the agent; threads that were declined (or need human judgment) stay unresolved so the reviewer can accept or reject the decision.

## Core Rules

1. **Unresolved comments only**: Unless explicitly told otherwise, only fetch and address comments where `is_resolved == false`. Use the `--unresolved` flag.
2. **Every thread gets a reply**: After assessing and acting on a comment, you MUST post a reply to that comment thread. No thread should be left without a response.
3. **Do not reply twice**: Before posting a reply, inspect the comments after the most recent `[Sesori reply]`. If the last comment is already a `[Sesori reply]` and there are no later reviewer comments, skip the thread. If the only later comments are acknowledgment-only bot comments (for example "Acknowledged", "Thanks", "Looks good", or "Accepted") with no new request, objection, question, or requested change, skip the thread. Do not skip if a later comment raises a follow-up, pushback, asks for clarification, or requests additional changes; handle that as a new actionable comment.
4. **Reply prefix**: Every reply must start with `[Sesori reply]` so it is clear the response comes from the agent, not the human user.
5. **Resolve what you fixed; leave what you declined**: After replying, RESOLVE the thread when its status is `Addressed` (fix implemented and pushed). Leave the thread UNRESOLVED when the status is `Not addressed`, `Partially addressed`, or `Question` — those carry a decision or an open point the human reviewer must be able to double-check and either accept (by resolving it themselves) or push back on.
6. **All comments are assessed**: Every comment must be evaluated for validity. Do not automatically assume any comment is correct.
7. **Extra scrutiny for AI/bot comments**: Comments from AI reviewers or bots require more careful assessment. They are more likely to be incorrect, irrelevant, or based on stale context.
8. **Human comments are trusted by default**: Comments from actual humans should be assumed valid unless you have a strong reason to believe they are wrong, detrimental, or cause likely unintended side effects.
9. **Single commit**: All fixes can be committed together in a single commit. The user squash-merges at the end.
10. **Never amend**: Always create new commits when addressing feedback. Do not use `git commit --amend`, `git rebase` to rewrite published history, or any other history-rewriting operation. If you make a mistake in a commit, fix it with a follow-up commit rather than rewriting.
11. **Never force push**: Do not use force push under any circumstances. If the remote branch has moved ahead of your local branch, pull/merge and continue with normal commits. History rewriting on a shared branch is forbidden.
12. **Outdated comments**: If `is_outdated == true`, assess whether the comment is still relevant. If the issue still exists in the current code, address it. If not, reply explaining why it is no longer applicable.

## Workflow

### Step 1: Fetch Unresolved Comments

Use the `pr-inline-comments` skill to fetch ONLY unresolved comments:

```bash
../pr-inline-comments/scripts/fetch.sh <pr-number> --unresolved [--repo OWNER/REPO]
```

If the user specifies a time window (e.g., "since yesterday"), also pass `--since <ISO_8601>`.

**Important:** The JSON output can be large and may get truncated in the terminal. Always save it to a file first:

```bash
../pr-inline-comments/scripts/fetch.sh <pr-number> --unresolved > /tmp/pr_comments.json
```

Then parse the file with `jq` or similar tools. You will receive an array of thread objects. Each thread contains:
- `thread_id`: The root comment ID (use this for posting replies)
- `path`: File path
- `line`: Line number
- `is_resolved`, `is_outdated`: Resolution status
- `comments[]`: Array of comments in the thread, each with `user`, `body`, `created_at`

### Step 2: Assess Each Comment

For each comment thread, read the relevant code and assess the comment's validity.

#### Validity Assessment

A comment is **valid** if:
- It correctly identifies a real issue (bug, style violation, architecture problem, missing test, etc.)
- The suggested change is appropriate and correct
- It is actionable and clear

A comment is **invalid** if:
- It is based on a misunderstanding of the code
- The suggestion would introduce a bug or worsen the code
- It is stylistically opinionated without project convention backing
- It suggests that the syntax is invalid but the analyzer accepts it
- It is outdated and no longer applies
- It is from an AI/bot and contains obvious hallucinations or generic advice

#### AI/Bot Identification

Apply extra scrutiny when the comment author (`user` field) matches any of these patterns:
- Username indicates author is a bot — commonly name contains: `bot`, `[bot]`, `github-actions`, `codex`, `gemini`, `copilot`, `claude`, `gpt`, `ai-`
- The comment uses very formal, mechanical, or templated language
- The suggestion is generic and lacks specific context about this codebase

For AI/bot comments:
- Verify the claim by reading the actual code
- Check if the suggestion aligns with existing codebase patterns
- Do not implement blindly — apply the same critical thinking you would use on your own code

#### Avoid the bot-review spiral

Every pushed commit can trigger a fresh round of AI-reviewer comments about new
edge cases, and fixing those spawns the next round. Do not loop indefinitely:

- **Raise the bar with each round.** A bot-reported edge case earns a code
  change only when it is plausible in a real user flow AND has a meaningful
  consequence (data loss, wrong routing, stuck UI). Contrived scenarios,
  cosmetic transients, and pre-existing behavior merely exposed by the PR get
  a `Not addressed` reply with the rationale — that is a fully valid
  resolution, not a failure.
- **Repeated findings in one seam are a signal, not a to-do list.** If several
  rounds of comments cluster around the same structural seam, stop patching
  point-by-point: fix the seam once at its root, or surface the pattern to the
  user as a possible design problem before writing more code.
- **Check comments against product direction.** A bot may flag intended
  behavior as a bug (it cannot know the roadmap). When a "fix" would move the
  code away from the stated direction, decline and say why.

#### Acknowledgment-only bot follow-ups

Some bots post a short acknowledgment after the `[Sesori reply]` instead of resolving the thread. Treat the thread as already addressed when every comment after the most recent `[Sesori reply]` is acknowledgment-only, such as "Acknowledged", "Thanks", "Looks good", "Accepted", or equivalent non-actionable wording.

Do not treat a bot follow-up as acknowledgment-only if it contains any of the following:
- a new requested change or clarification
- a question about the fix
- a pushback or objection
- a statement that the previous reply did not address the original concern
- a new link, suggestion, or actionable review note

For human follow-ups, assume the follow-up is actionable unless it is explicitly just an acknowledgment.

For human comments:
- Assume the comment is correct unless you have strong evidence otherwise
- If you disagree, still explain your reasoning in the reply
- If you disagreed with a given reason, but the human replied to still go ahead and do it, you must proceed with the requested task

### Step 3: Implement Fixes

For each valid comment:

1. Read the file(s) referenced in the comment
2. Understand the context around the commented line
3. Make the minimal, correct fix
4. Verify the fix does not break existing functionality
5. If multiple comments affect the same file, batch the changes

Fix guidelines:
- Fix minimally. Do not refactor unrelated code.
- A small, safe hardening or cleanup a reviewer flags **inside a file or class your PR already modifies** is in scope — implement it rather than declining it as "pre-existing" or "out of scope." Reserve those reasons for genuinely unrelated files or large/risky refactors.
- Follow existing codebase conventions (style, naming, patterns)
- If a comment requests a specific approach and you disagree, use your judgment but explain in the reply
- If you are changing logic or fixing logic bugs/edge case omissions/etc, use TDD (write a failing test first)
- Do not suppress type errors with `as any`, `@ts-ignore`, or `@ts-expect-error`

### Step 4: Commit and Push Changes

After all fixes have been implemented, check the worktree status first. If there are pre-existing modifications or untracked files unrelated to the PR comments, warn the user and ask whether to proceed before committing.

```bash
git status
```

If the worktree is clean except for the files you modified for the PR comments, stage and commit only those files:

```bash
git add <file1> <file2> ...
git commit -m "fix: address PR review comments"
```

**Never** stage unrelated work in a PR feedback commit. Do not use `git add -A`.

Or use a more specific message if the changes are purely stylistic or architectural:

```bash
git commit -m "refactor: address PR review feedback"
```

Then push the commit so the fixes are visible on the remote branch:

```bash
git push origin <branch-name>
```

**Important:** Always commit and push BEFORE posting replies. If you post "Addressed" before pushing, the fixes won't be visible to reviewers, making the replies misleading.

**Important:** Never rewrite history when addressing PR feedback. Do not amend commits and do not force push. If the remote branch has diverged, pull/merge normally and add new commits on top. The user squash-merges at the end, so a linear chain of fix commits is expected.

**No changes to commit:** If all fetched comments were invalid, outdated, or questions requiring no code change, skip the commit and push steps. Proceed directly to posting replies.

### Step 5: Leave Replies

After the commit has been successfully pushed, post a reply to each comment thread explaining what was done.

**Reply format for Addressed and Partially addressed:**
```
[Sesori reply] <status> (in commit <commit_hash>)

<detailed explanation>
```

The explanation must describe **what** was changed and **why**, not just restate the status. A reply that only says "Addressed" or "Fixed" is insufficient.

**Be concise.** Say only what is meaningful. If you did exactly what was requested with no side effects or additional context needed, a single sentence like "Renamed `foo` to `bar` as requested" is enough. Only add more detail when there is genuinely something worth communicating — e.g., the fix caused a related change elsewhere, you rejected part of the suggestion for a specific reason, or the change has implications the reviewer should know about. Do not add pointless fluff.

**Reply format for Not addressed and Question:**
```
[Sesori reply] <status>

<explanation>
```

Where `<status>` is one of:
- `Addressed` — The fix has been implemented and pushed
- `Not addressed` — The comment was assessed as invalid or not applicable
- `Partially addressed` — Part of the request was implemented, part was not
- `Question` — The comment is unclear and needs clarification from the reviewer

**Examples:**

Addressed (simple fix):
```
[Sesori reply] Addressed (in commit a1b2c3d)

Changed the loop boundary from `i <= n` to `i < n` in `src/utils.ts` to fix the off-by-one error.
```

Addressed (complex fix requiring more context):
```
[Sesori reply] Addressed (in commit a1b2c3d)

Extracted the retry logic into a separate `RetryService` in `src/services/retry_service.dart`. This centralizes the backoff strategy and makes it reusable across the HTTP client and the WebSocket reconnect flow.
```

Not addressed (AI comment found invalid):
```
[Sesori reply] Not addressed

This suggestion would introduce a race condition. The current implementation already handles synchronization correctly via the existing mutex.
```

Not addressed (outdated):
```
[Sesori reply] Not addressed

This comment refers to code that has been refactored in a subsequent commit. The variable in question no longer exists.
```

Partially addressed:
```
[Sesori reply] Partially addressed (in commit a1b2c3d)

Renamed the function as requested. Did not remove the platform abstraction because it would break Windows support and duplicate OS detection logic.
```

Question:
```
[Sesori reply] Question

Could you clarify what you mean by "optimize this"? Are you looking for time complexity improvements or reduced memory usage?
```

**Posting replies via helper script:**

Use the included `reply.sh` helper script:

```bash
./scripts/reply.sh <pr-number> <thread_id> "Addressed: Fixed the null check."
```

The script automatically prefixes the body with `[Sesori reply]` if not already present.

### Step 6: Resolve the Addressed Threads

After the reply is posted, resolve every thread whose status is `Addressed`,
using the included `resolve.sh` helper (thread resolution requires the GraphQL
API; the script maps the comment id to its thread and is idempotent):

```bash
./scripts/resolve.sh <pr-number> <thread_id>
```

Do NOT resolve threads replied with `Not addressed`, `Partially addressed`, or
`Question`. Those stay open on purpose: the human reviewer reads the rationale
and either agrees (resolving the thread themselves) or pushes back — an
unresolved thread is the review-queue signal for that decision. Resolving a
declined thread would hide the disagreement.

## Edge Cases

### Comment on a file not in the working tree

If the comment references a file that does not exist in your working tree (e.g., the PR added it and you are on a different branch), ask the user whether they want you to change the current branch or worktree before proceeding. There is a chance the user asked in the wrong session to review a PR.

### Multiple comments on the same line

If multiple threads reference the same line, address each independently. They may be about different issues.

### Comments requesting architectural changes

If a human reviewer requests a significant architectural change, implement it without complaining — even if it requires refactoring multiple files. Do not push back or suggest creating a follow-up issue unless you have a strong technical reason to believe the change is wrong.

For AI/bot comments requesting large architectural changes, apply normal validity assessment. If the suggestion is genuinely reasonable, implement it. If it is misguided, reply explaining why it is not viable.

### Comments with no clear action

Some comments are questions or discussions without a clear requested change. Reply to these with `[Sesori reply] Question:` or `[Sesori reply] Not addressed:` and explain why no code change is needed.

### Resolved comments that the user wants revisited

If the user explicitly asks you to look at resolved comments, omit the `--unresolved` flag when fetching. Apply the same assessment and reply process.

## Dependencies

- `gh` (authenticated via `gh auth login`)
- `pr-inline-comments` skill (for fetching comments)
- Access to the repository working tree (to read and edit files)

## Determining the PR Number

If the user invokes this skill without an explicit PR number (e.g. "address the PR comments" or "review feedback"), assume they are referring to the most recently raised PR in the current session. Look at the recent conversation for the latest PR URL or number; if in doubt, ask the user to confirm before fetching comments.

## Example Session

User: "Address the comments on PR 42"

1. Fetch unresolved comments using the `pr-inline-comments` skill
2. Receive 3 threads:
   - Thread 1 (human): "This loop has an off-by-one error"
   - Thread 2 (bot): "Consider using a more functional approach"
   - Thread 3 (human): "Missing null check here"
3. Assess:
   - Thread 1: Valid. Fix the loop boundary.
   - Thread 2: AI suggestion. Current imperative approach is clearer here. Do not implement.
   - Thread 3: Valid. Add null check.
4. Implement fixes for threads 1 and 3.
5. Make a single commit and push
6. Post replies:
   - Thread 1: `[Sesori reply] Addressed (in commit a1b2c3d)\n\nChanged the loop boundary from i <= n to i < n in src/utils.ts to fix the off-by-one error.]`
   - Thread 2: `[Sesori reply] Not addressed\n\nThe current imperative approach is intentional and more readable here.]`
   - Thread 3: `[Sesori reply] Addressed (in commit a1b2c3d)\n\nAdded null check in src/services/user_service.dart before accessing user.email.`
7. Resolve threads 1 and 3 (`./scripts/resolve.sh 42 <thread_id>`). Thread 2
   stays unresolved for the reviewer to accept or reject the decision.
