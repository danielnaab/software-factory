{% if args is defined %}
## Task

{{ args }}
{% endif %}

{% if state.verify is defined %}
## Verification Status

### Format
{{ state.verify.format }}

### Lint
{{ state.verify.lint }}

### Tests
{{ state.verify.tests }}
{% endif %}

{% if state.changes is defined %}
## Recent Changes

### Commits
{{ state.changes.commits }}

### Working Tree
{{ state.changes.diff }}
{% endif %}

## Plan Format

Structure your plan as a story with vertical slices. Each slice is an independently verifiable increment that leaves the codebase passing — this limits blast radius when something goes wrong.

If the task is a single-file change, output one slice. Do not over-decompose.

### Story

One sentence: what capability this delivers and why.

### Approach

One paragraph: the architectural strategy. Which existing patterns to extend, what the integration points are, what the dependency order is between changes.

### Acceptance Criteria

Bulleted end-to-end conditions. Use concrete verification commands from AGENTS.md where possible. Include edge cases.

### Slices

Ordered list. For each:

- **Delivers** -- what user-facing capability this adds
- **Done when** -- verifiable criteria referencing specific tests or commands
- **Files** -- specific files to modify or create

Include spec and doc changes in the same slice as the code they describe.
