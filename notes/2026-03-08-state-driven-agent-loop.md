---
status: working
purpose: "Session note: redesigning software-factory around state-driven agent invocations with retry"
---

# State-Driven Agent Loop

Session exploring a simplification of software-factory's command architecture. Instead of many commands with per-phase prompt templates, one generic agent invocation reads repo state to decide what to do. External retry drives the convergence loop.

## Problem with current architecture

Software-factory has 8 commands, 5 scripts, 4 prompt templates, and 2 sequences. Each command is a stateless function: launch Claude, pipe a specific prompt, Claude does one thing, exits.

This creates accidental complexity:

- **`implement` vs `resume`** exist because each invocation is fresh. Resume reconstructs context from `session.json`, `context-snapshot.json`, `diagnose.json`. A state-aware agent doesn't need two commands -- it reads the state and knows what to do.
- **Sequences** (`implement-verified`, `implement-reviewed`) chain stateless invocations with retry logic. External orchestration compensating for agents that can't loop.
- **Prompt templates** (`review.md`, `diagnose.md`) are per-phase instructions piped via stdin. Separate entry points for what should be phases within a single agent's judgment.
- **`context` queries** pre-compute state and inject it into templates before launch. Necessary when agents can't gather their own context. Unnecessary when the agent has shell access.

## Core idea

One command. One prompt. State drives behavior. Retry drives the loop.

```yaml
scions:
  start:
    run: "claude -p --dangerously-skip-permissions"
    retry:
      until: success
      max: 30
```

The stdin prompt is generic:

> Read CLAUDE.md for project conventions. Read slices/$GRAFT_SCION_NAME/plan.md for your task. Implement the next unchecked step. Run verification. Fix failures. Mark the step done when verification passes. Exit 0 when all steps are done and verification passes. Exit 1 if more work remains. Exit 2 if you are blocked.

Each invocation is one turn. The agent reads state, does one unit of work, exits. Graft re-invokes on exit 1. The loop is dumb -- the intelligence is in the agent reading state.

## What collapses

| Before | After |
|--------|-------|
| `implement` command | One generic command |
| `resume` command | Gone -- state IS the resume |
| `review` command | Agent self-reviews as part of its loop |
| `diagnose` command | Agent diagnoses failures when verify output says so |
| `verify` command | Agent runs `scripts/verify.sh` itself |
| `implement-verified` sequence | Gone -- retry replaces sequences |
| `implement-reviewed` sequence | Gone |
| `implement-session.sh` | Trivial or gone |
| `resume-session.sh` | Gone |
| `review-run.sh`, `diagnose-run.sh`, `spec-check-run.sh` | Gone |
| `plan.md`, `review.md`, `diagnose.md`, `spec-check.md` templates | One thin prompt or just CLAUDE.md |
| `context` queries in command config | Gone -- agent gathers its own context |

**Before:** 8 commands, 5 scripts, 4 templates, 2 sequences.
**After:** 1 command, 0-1 scripts, 1 prompt, 0 sequences.

## What remains

- **`plan`** and **`new-slice`** -- these happen before a scion exists. Pre-work, not part of the agent loop. May survive as standalone commands or become human-authored artifacts.
- **`verify`** -- still a deterministic shell script. But the agent calls it directly rather than graft orchestrating it as a separate command.
- **Scion lifecycle** -- `create`, `fuse`, `prune`, `list`, `attach` are git/tmux operations. Grove keeps those.
- **File conventions** -- plan format, frontmatter, step structure. The plan IS the instruction set.

## Exit codes as the protocol

| Exit | Meaning | Graft action |
|------|---------|-------------|
| 0 | Done -- all steps complete, verify passes | Stop, report success |
| 1 | Work done, more remains | Re-invoke |
| 2 | Blocked, need human help | Stop, notify human |

Files are the rich state channel. Exit codes are the control flow channel. That's the whole protocol.

## Why `context` queries aren't needed

Context queries pre-compute state and inject it into prompt templates. With `--dangerously-skip-permissions`, Claude can:

- Run `scripts/verify.sh` directly
- Read `slices/*/plan.md` directly
- Run `git diff`, `git log`
- Read any file in the repo

The agent gathers its own context. The prompt just says "here's where to look." CLAUDE.md already does that.

A pre-computed summary at launch (e.g., current slice status) could save the agent a few file reads. But that's a performance optimization, not an architectural necessity.

## The retry primitive

This is the key new graft concept. Any command can declare retry behavior:

```yaml
retry:
  until: success   # re-invoke on non-zero exit
  max: 30          # safety limit
```

The retry primitive is not agent-specific. It works for any command: flaky tests, convergence deployments, build retries. Software-factory uses it for the agent loop, but it's a graft-level feature.

### Session continuity across retries

Each retry can be a fresh Claude session or a resumed one:

```bash
exec claude -p --session-id "graft-scion-$GRAFT_SCION_NAME" \
  --dangerously-skip-permissions
```

With `--session-id`, each retry continues the previous conversation. Claude has memory of what it tried and what failed. Fresh state-reading and session continuity aren't mutually exclusive.

Without `--session-id`, each retry is a cold start that reads state from files. Still works -- the plan's checked/unchecked steps and verify results provide full situational awareness. Just less efficient.

## The plan as a state machine

Each `- [ ]` / `- [x]` transition is a state change. The agent reads the state machine (the plan), advances it one step, and exits. The retry loop drives the state machine forward.

This is a convergence loop: each invocation moves closer to the goal state (all steps done, verify passing). The external loop doesn't know what the goal is -- it just re-invokes until exit 0.

## What software-factory becomes

Instead of a command library, software-factory defines:

1. **File conventions** -- where plans live, frontmatter format, step structure
2. **A single agent prompt** -- "read the plan, do the work, verify, exit"
3. **Lifecycle hooks** -- on_create, pre_fuse (verify gate), post_fuse
4. **The retry contract** -- exit code semantics

The "process" is encoded in the repo's own documentation (CLAUDE.md, AGENTS.md, the plan), not in external orchestration.

## New ideas

### Commands as state mutations

Instead of `:run software-factory:review`, the human edits a file or writes a signal. The running agent (or the next retry invocation) reads updated state and adjusts. Human and agent use the same interface -- file edits.

### Multiple scions as parallel convergence loops

Each scion is an independent retry loop working toward its own plan's goal state. Grove monitors all of them. When one converges (exit 0), it's ready to fuse. Naturally parallel, no orchestration.

### Human intervention is state mutation

If Claude exits 2 (blocked), the human attaches, fixes the issue, and restarts. The next invocation reads updated state and continues. Or the human edits the plan to clarify a step, then resumes the loop.

### Review as a verify gate

Instead of a separate review command, self-review is part of what the agent does before marking a step done. Or it's a pre_fuse hook -- before fusing, run a review check. Same convergence pattern.

### The retry primitive generalizes

Exit-code-driven hooks: exit 0 triggers pre_fuse. Exit 2 triggers human notification. Exit 1 triggers retry. The scion lifecycle becomes event-driven.

## Risks and mitigations

- **Runaway cost** -- `max` limit caps total invocations. Exit 2 lets the agent self-identify when stuck.
- **State corruption** -- if the agent writes bad state, every retry fails the same way. Verify acts as a correctness gate. Pre_fuse hooks are a final quality gate.
- **Loss of granularity** -- individual commands gave humans control over each phase. `:attach` is the escape valve for steering.
- **Exit code reliability** -- `claude -p` exit code semantics need verification. The script wrapper may need to interpret output to set the exit code.

## Relationship to existing research

This aligns with findings from the [workflow design research](2026-02-21-workflow-design-research.md):

- **MAKER study**: zero-error completion via maximal decomposition. The plan provides decomposition; the retry loop executes it step by step.
- **Anthropic two-agent pattern**: initializer + coding agent with cross-session memory. Here, the plan is the initializer's output, and session continuity (`--session-id`) provides memory.
- **Ralph Loop**: implement -> verify -> self-critique -> fix. Same loop, but driven by graft retry instead of a bash script.
- **Anti-pattern avoidance**: the "auto-implement (unbounded loop)" anti-pattern is mitigated by the `max` limit and exit 2 (blocked) signal. This is bounded, not unbounded.

## Next steps

1. Define the retry primitive in graft's command spec (graft-level, not software-factory-specific)
2. Prototype the simplified scion start hook with one agent prompt
3. Test exit code behavior with `claude -p --dangerously-skip-permissions`
4. Decide whether `plan` and `new-slice` survive as separate commands or become human-authored
5. Update the [slice implementation workflow](../docs/slice-implementation-workflow.md) to reflect the simplified model
