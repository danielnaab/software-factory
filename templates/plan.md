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

The story is a vertical slice — a thin, end-to-end increment of capability. Steps are the implementation sequence to deliver it. Each step leaves the codebase passing so that blast radius is limited when something goes wrong.

If the task is a single-file change, output one step. Do not over-decompose.

### Story

One sentence: what capability this delivers and why.

### Approach

One paragraph: the architectural strategy. Which existing patterns to extend, what the integration points are, what the dependency order is between changes.

### Acceptance Criteria

Bulleted end-to-end conditions that describe how the feature behaves, not just how to verify it compiles. Include edge cases and failure modes.

### Steps

Ordered list. For each:

- **Delivers** -- what user-facing capability this adds
- **Done when** -- observable behavior that confirms this step works
- **Files** -- specific files to modify or create

Include spec and doc changes in the same step as the code they describe.
