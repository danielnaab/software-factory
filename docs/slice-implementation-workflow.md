---
status: draft
---

# Slice implementation workflow

Step-by-step process for taking a slice from draft to done using grove, scions, and software-factory commands.

## Prerequisites

- A draft slice exists at `slices/<slug>/plan.md` with steps, acceptance criteria, and dependencies
- All slices in the `depends_on` list are done
- `graft resolve` has been run (`.graft/` dependencies are current)
- Consumer project has `scripts/verify.sh`

## Two paths: interactive and scion

**Interactive** (`:run`) — synchronous, output streams to grove transcript. Good for quick commands: verify, review, plan, one-off implement.

**Scion** (`:scion`) — creates an isolated worktree with a background tmux session running Claude Code. Good for sustained implementation across multiple steps. Each scion gets its own branch (`feature/<name>`), state directory, and session persistence.

The scion path is the primary workflow. Interactive is for spot checks and quick tasks.

## Workflow

### 1. Pick and focus a slice

Open grove and review what's available:

```
grove
:state slices
```

Choose a draft slice whose dependencies are satisfied. Focus on it:

```
:focus slices
```

This opens a picker over all slices. Select your target. Focus is sticky — subsequent commands that take a `slice` argument will auto-fill it. You can also set focus directly:

```
:focus slices slices/<slug>
```

Read the plan to understand the story, approach, and acceptance criteria:

```
:run software-factory:plan
```

### 2. Accept the plan

No grove command for this yet — edit `slices/<slug>/plan.md` directly. Change the frontmatter status from `draft` to `accepted`. If the plan needs changes, edit it first. Steps should be small, independently verifiable, and completable in one session.

### 3. Create a scion

```
:scion create <name>
```

This creates a git worktree at `.worktrees/<name>/` and a branch `feature/<name>`. The scion is an isolated copy of the repo where implementation happens without affecting main.

Name the scion after the slice (e.g., `:scion create grove-durable-error-messages`).

### 4. Start the scion

```
:scion start <name>
```

This launches the command configured in `graft.yaml` under `scions.start` (typically `software-factory:implement`) inside a tmux session in the scion's worktree. The implement session:
- reads the slice plan
- finds the next unchecked step (`- [ ]`)
- implements exactly what the step requires
- runs verification
- marks the step done (`- [x]`) if verification passes

### 5. Attach to monitor progress

```
:attach <name>
```

This connects your terminal to the scion's tmux session so you can watch Claude Code work, intervene, or provide input. Detach with `Ctrl-b d` to return to grove.

### 6. Monitor from grove

Without attaching, check scion status:

```
:scion list
```

Shows each scion's ahead/behind counts, dirty state, session activity, and verify status.

### 7. Iterate

If the session completes one step and stops, start it again for the next step:

```
:scion start <name>
```

If a step failed, resume picks up with context from the previous attempt:

```
:run software-factory:resume <slug>
```

Repeat until all steps in the plan are checked off.

### 8. Verify and review

Run verification from the scion worktree or interactively:

```
:run software-factory:verify
:run software-factory:review
```

Review is an adversarial self-review of the diff against acceptance criteria.

### 9. Fuse the scion

When all steps pass and the slice is complete:

```
:scion fuse <name>
```

This merges the scion's branch into main, runs pre/post-fuse hooks, and cleans up the worktree and branch. If verify fails during fuse hooks, fix and retry.

### 10. Mark the slice done and move on

Edit `slices/<slug>/plan.md` — change frontmatter status to `done`. Commit.

Check what's newly unblocked. Slices that depended on the completed one may now be ready.

## Interactive shortcuts

For quick, synchronous work without creating a scion:

```
:run software-factory:implement <slug>          # one step, blocking
:run software-factory:implement-verified <slug> # implement + verify, retry up to 3x
:run software-factory:implement-reviewed <slug> # implement + verify + review
```

When focus is set on `slices`, the `<slug>` argument auto-fills.

## Dependency order for current draft slices

Independent (can start in any order):
- `grove-smart-column-widths` — table readability at narrow widths
- `grove-focus-navigation` — circular Tab, auto-scroll, Esc unfocus
- `grove-block-visual-clarity` — gutter markers for block boundaries
- `grove-catalog-arg-prompt` — pre-fill prompt for commands needing args
- `grove-state-query-execution` — execute state queries from TUI

Requires `grove-durable-error-messages` first:
- `grove-dep-config-error-diagnostics` — surface graft.yaml load failures
- `grove-actionable-scion-errors` — append fix hints to scion errors

Suggested order:
1. `grove-durable-error-messages` (unblocks 2 others)
2. Any independent slices (parallel-safe via separate scions)
3. `grove-dep-config-error-diagnostics`
4. `grove-actionable-scion-errors`

## Principles

- **One step at a time.** Each step leaves the codebase green.
- **Read the plan before coding.** Understand acceptance criteria, not just the step title.
- **Small steps over big steps.** If a step feels too large, split it in the plan first.
- **Verify before marking done.** Never mark a step `[x]` with failing checks.
- **Edit the plan when it's wrong.** Plans are living documents. Update them when reality diverges.
- **Fuse early.** Don't let scions drift far from main. Fuse after each slice, not after several.

## Context

- [Prompt templates spec](specifications/prompt-templates.md)
- [Agent workflow](../../meta-knowledge-base/docs/playbooks/agent-workflow.md)
- [Style policy](../../meta-knowledge-base/docs/policies/style.md)
