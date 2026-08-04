---
name: architecture-implementation-review
description: Reviews architecture-bearing production changes, not general implementation correctness. Must be invoked as a sub-agent: the main agent should ask a sub-agent to perform the review using this skill, rather than loading the skill directly in the main agent context. Prefers Git scopes such as a branch, commit range, recent commits, or PR, but also accepts file-based scopes. Avoids legacy-cleanup scope creep; callers seek user guidance after two rejected passes.
---

# architecture-implementation-review (Claude Code shim)

Read `.agents/skills/architecture-implementation-review/SKILL.md` now and follow it in full.
