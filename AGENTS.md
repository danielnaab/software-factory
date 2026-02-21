# Agent Entrypoint - Software Factory

You are working in the **software-factory knowledge base** -- a repository defining reusable patterns for evolving agent-authored codebases.

## Quick Orientation

| Path | Purpose |
|------|---------|
| `knowledge-base.yaml` | KB structure declaration |
| `README.md` | Human entrypoint |
| `AGENTS.md` | Agent entrypoint (this file) |
| `docs/` | Pattern documentation and [specifications](docs/specifications/) |
| `templates/` | Prompt templates consumed by graft commands ([spec](docs/specifications/prompt-templates.md)) |
| `notes/` | Time-bounded exploration notes |
| `.graft/` | Dependencies managed via `graft resolve` |

## Key Policies

Follow [meta knowledge base conventions](.graft/meta-knowledge-base/AGENTS.md):

1. **Authority**: docs/ is canonical for patterns; notes/ are ephemeral
2. **Provenance**: Ground pattern recommendations in project experience
3. **Lifecycle**: Mark status (draft/working/stable/deprecated)
4. **Write boundaries**: See `rules.writes` in `knowledge-base.yaml`

## Workflow: Plan -> Patch -> Verify

Follow the [agent workflow pattern](.graft/meta-knowledge-base/docs/playbooks/agent-workflow.md):

1. **Plan**: State intent, files to touch, uncertainties
2. **Patch**: Smallest diffs that achieve the goal
3. **Verify**: Run checks or specify what human should verify

## Write Boundaries

You may write to:
- `docs/**` -- pattern documentation
- `templates/**` -- prompt templates
- `notes/**` -- session logs and explorations

Never write to:
- `.graft/**` -- managed dependencies
- `secrets/**`, `credentials/**` -- sensitive paths

## Navigation

- Patterns and specs: `docs/`
- Templates: `templates/`
- Notes: [notes/](notes/)
- Dependencies: [meta-knowledge-base](.graft/meta-knowledge-base/), [living-specifications](.graft/living-specifications/)
