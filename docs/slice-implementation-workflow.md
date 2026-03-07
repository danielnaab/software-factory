---
status: draft
---

# Slice implementation workflow

Step-by-step process for taking a slice from draft to done using grove and software-factory commands.

## Prerequisites

- A draft slice exists at `slices/<slug>/plan.md` with steps, acceptance criteria, and dependencies
- All slices in the `depends_on` list are done
- `graft resolve` has been run (`.graft/` dependencies are current)
- Consumer project has `scripts/verify.sh`

## Workflow

### 1. Pick a slice

Open grove and review what's available:

```
grove
:state slices
```

Choose a draft slice whose dependencies are satisfied. Read the plan:

```
:run software-factory:plan
```

Or read `slices/<slug>/plan.md` directly. Understand the story, approach, and acceptance criteria before starting.

### 2. Accept the plan

If the plan is ready, change the frontmatter status from `draft` to `accepted`. If the plan needs changes, edit it first -- steps should be small, independently verifiable, and completable in one session.

### 3. Implement one step

Start implementation with:

```
:run software-factory:implement <slug>
```

This launches a Claude session that:
- reads the plan
- finds the next unchecked step (`- [ ]`)
- implements exactly what the step requires
- runs verification
- marks the step done (`- [x]`) if verification passes

One step per invocation. If the step is large, break it up in the plan first.

### 4. Verify

Verification runs automatically at the end of implement. To run it separately:

```
:run software-factory:verify
```

This calls `scripts/verify.sh` (format, lint, tests, smoke). All four must pass.

If verification fails, either fix manually or use resume:

```
:run software-factory:resume <slug>
```

Resume reads the previous session context and diagnosis, then picks up where implement left off.

### 5. Review (optional)

After implementation passes verification:

```
:run software-factory:review
```

Adversarial self-review of the diff against acceptance criteria. Outputs `review.json` with findings. Address any issues before proceeding.

### 6. Repeat until all steps are done

Go back to step 3 for the next unchecked step. Each step should leave the codebase green (all verification passing).

### 7. Mark the slice done

When all steps are checked off and verification passes:
- Change frontmatter status to `done`
- Commit the final plan update

### 8. Move to the next slice

Check what's unblocked. Slices that depended on the one you just completed may now be ready.

## Shortcut: implement-verified sequence

For hands-off operation, the `implement-verified` sequence runs implement then verify, with automatic retry on verification failure (up to 3 attempts):

```
:run software-factory:implement-verified <slug>
```

## Shortcut: implement-reviewed sequence

Same as above but adds a self-review after verification passes:

```
:run software-factory:implement-reviewed <slug>
```

## Dependency order for current draft slices

Independent (can start in any order):
- `grove-smart-column-widths` -- table readability at narrow widths
- `grove-focus-navigation` -- circular Tab, auto-scroll, Esc unfocus
- `grove-block-visual-clarity` -- gutter markers for block boundaries
- `grove-catalog-arg-prompt` -- pre-fill prompt for commands needing args
- `grove-state-query-execution` -- execute state queries from TUI

Requires `grove-durable-error-messages` first:
- `grove-dep-config-error-diagnostics` -- surface graft.yaml load failures
- `grove-actionable-scion-errors` -- append fix hints to scion errors

Suggested order:
1. `grove-durable-error-messages` (unblocks 2 others)
2. Any independent slices (parallel-safe)
3. `grove-dep-config-error-diagnostics`
4. `grove-actionable-scion-errors`

## Principles

- **One step at a time.** Each step leaves the codebase green.
- **Read the plan before coding.** Understand acceptance criteria, not just the step title.
- **Small steps over big steps.** If a step feels too large, split it in the plan first.
- **Verify before marking done.** Never mark a step `[x]` with failing checks.
- **Edit the plan when it's wrong.** Plans are living documents. Update them when reality diverges.

## Context

- [Prompt templates spec](specifications/prompt-templates.md)
- [Agent workflow](../../meta-knowledge-base/docs/playbooks/agent-workflow.md)
- [Style policy](../../meta-knowledge-base/docs/policies/style.md)
