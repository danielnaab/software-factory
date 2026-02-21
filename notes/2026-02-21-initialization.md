---
status: working
purpose: "Session note: bootstrapping the software-factory repository"
---

# Software Factory Initialization

## What We Did

Bootstrapped the software-factory repository with foundational files:

- `graft.yaml` -- declares dependencies on meta-knowledge-base and living-specifications
- `knowledge-base.yaml` -- KB structure following established conventions
- `README.md` -- human-facing overview
- `AGENTS.md` -- agent entrypoint following meta-KB patterns
- This session note

## Purpose

Software factory fills the **process layer** in the knowledge base ecosystem. The existing dependencies address:

- **meta-knowledge-base** -- how to organize knowledge (governance)
- **living-specifications** -- how to write and maintain specs (methodology)
- **python-starter** / **rust-starter** -- how to structure code (architecture)

None of these address how agents and humans collaborate to evolve a codebase over time. That knowledge currently lives scattered across project-specific files in graft: AGENTS.md conventions, continue-here.md handoffs, Ralph Loop scripts, verification protocols. Software factory generalizes these into reusable patterns.

## Relationship to Graft and Grove

Software factory is both a graft dependency (consumed by other projects) and a graft consumer (it uses graft for its own dependencies). This creates a useful feedback loop:

- **Graft provides the plumbing** -- dependency resolution, submodule management
- **Software factory provides the process** -- how agents use that plumbing effectively
- **Grove provides the workspace** -- multi-repo coordination where these patterns apply

## Follow-Up Topics to Explore

These are candidate areas for specification. No priority order yet -- each needs a session to scope what's worth formalizing vs. what should stay project-specific.

### Ralph Loop autonomous iteration protocol

The pattern of `ralph.sh` + prompt template + plan/progress files for autonomous agent iteration. Currently duplicated per-task in graft's notes/. Questions: what's the minimal protocol? How much is the loop vs. the prompt engineering?

### Agent entrypoint conventions

AGENTS.md and CLAUDE.md serve different roles. AGENTS.md is the canonical agent entrypoint for a knowledge base. CLAUDE.md is tool-specific (Claude Code). What belongs in each? What's the relationship? Are there conventions for other tools?

### Session management

The continue-here.md pattern for session handoff. What to capture (current state, next steps, blockers), when to archive, how to bridge context across stateless agent invocations.

### Verification and self-critique protocols

The commit-then-critique cycle. How to structure verification commands, when to split vs. combine tasks, the role of self-review in maintaining quality.

### Progress tracking and consolidated patterns

Append-only progress logs, the consolidated patterns approach for distilling insights from multiple sessions, how to prevent knowledge loss across context windows.

### Bridge pattern for incremental migrations

The pattern used in graft's Python-to-Rust migration: maintaining both implementations, parity verification, gradual feature migration. Generalizable to any large codebase evolution.
