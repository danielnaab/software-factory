# Software Factory

Reusable patterns for evolving agent-authored codebases.

## What This Is

Software factory captures the process layer of agent-human collaboration on code. It generalizes patterns proven in real projects into reusable protocols and conventions that any codebase can adopt.

This is distinct from architecture patterns (how to structure code) or specification methodology (how to write specs). Software factory addresses how agents and humans work together to evolve a codebase over time.

## Current State

This repository is bootstrapping. No specifications have been written yet. See [notes/](notes/) for current thinking on what to formalize.

## Potential Topics

- Autonomous iteration protocols (the Ralph Loop)
- Agent entrypoint conventions (AGENTS.md, CLAUDE.md)
- Session management and handoff (continue-here.md pattern)
- Verification and self-critique protocols
- Progress tracking across stateless agent invocations
- Bridge patterns for incremental migrations

## Using This

Add as a graft dependency:

```yaml
# graft.yaml
apiVersion: graft/v0
deps:
  software-factory: "https://github.com/danielnaab/software-factory.git#main"
```

Then reference patterns from `.graft/software-factory/docs/`.

## Navigation

- [Notes](notes/) - Exploration and session logs
- [Configuration](knowledge-base.yaml) - KB structure declaration
- [Agent entrypoint](AGENTS.md) - For AI agents working in this repo
