---
name: address-pr-comments
description: Address unresolved inline PR review comments on a GitHub pull request. Fetches unresolved comments, assesses validity (with extra scrutiny for AI/bot reviewers), implements fixes, leaves a reply on every comment thread, and commits changes. Use when the user asks to address PR comments, resolve review feedback, implement requested changes, or handle PR review threads.
---

# address-pr-comments

Addresses unresolved inline PR review comments by assessing their validity, implementing fixes, and leaving a reply on each comment thread. Every thread gets a response — either confirming the fix or explaining why the comment was not addressed.

## Core Rules

1. **Unresolved comments only**: Unless explicitly told otherwise, only fetch and address comments where `is_resolved == false`. Use the `--unresolved` flag.
2. **Every thread gets a reply**: After assessing and acting on a comment, you MUST post a reply to that comment thread. No thread should be left without a response.
3. **Do not reply twice**: Before posting a reply, check the thread's `comments[]` for an existing body starting with `[Sesori reply]`. If the last comment in the thread is already a `[Sesori reply]`, skip the thread unless there is a new follow-up request from a reviewer. If the last comment is an acknowledgment like "Acknowledged" or similar that does not require action, skip it.
4. **Reply prefix**: Every reply must start with `[Sesori reply]` so it is clear the response comes from the agent, not the human user.
5. **All comments are assessed**: Every comment must be evaluated for validity. Do not automatically assume any comment is correct.
6. **Extra scrutiny for AI/bot comments**: Comments from AI reviewers or bots require more careful assessment. They are more likely to be incorrect, irrelevant, or based on stale context.
7. **Human comments are trusted by default**: Comments from actual humans should be assumed valid unless you have a strong reason to believe they are wrong, detrimental, or cause likely unintended side effects.
8. **Single commit**: All fixes can be committed together in a single commit. The user squash-merges at the end.
9. **Outdated comments**: If `is_outdated == true`, assess whether the comment is still relevant. If the issue still exists in the current code, address it. If not, reply explaining why it is no longer applicable.

## Workflow

### Step 1: Fetch Unresolved Comments

Use the `pr-inline-comments` skill to fetch ONLY unresolved comments:

```bash
../pr-inline-comments/scripts/fetch.sh <pr-number> --unresolved [--repo OWNER/REPO]
```

If the user specifies a time window (e.g., "since yesterday"), also pass `--since <ISO_8601>`.

Parse the JSON output. You will receive an array of thread objects. Each thread contains:
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

**Important:** DO NOT use force push without explicit per-instance consent. Do not assume that you can use force push again just because the user allowed it previously.

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
