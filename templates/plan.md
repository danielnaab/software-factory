Read AGENTS.md for project conventions, verification commands, and write boundaries.
Explore the codebase to understand relevant files and existing patterns before planning.

{% if state.verify is defined %}
## Verification Status

{{ state.verify.raw }}
{% endif %}

{% if state.changes is defined %}
## Recent Changes

{{ state.changes.raw }}
{% endif %}

## Plan Format

Plan the task given to you. Structure your plan as a story with vertical slices.

### Story

One sentence: what capability this delivers and why.

### Acceptance Criteria

Bulleted list of end-to-end conditions that must be true when all slices are complete.

### Slices

Ordered list of independently-testable increments. For each:

- **Delivers** -- what user-facing capability this adds
- **Done when** -- concrete acceptance criteria for this slice alone
- **Files** -- specific files to modify or create

Each slice should leave the codebase in a passing state. Include spec and doc changes in the same slice as the code they describe.
