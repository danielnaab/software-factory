---
status: draft
last-verified: 2026-02-21
---

# Prompt Templates

## Intent

Define the contract between software-factory templates and consumer repositories. Templates provide workflow structure (context slots, output format); consumers provide project-specific substance (state queries, execution commands).

## Non-goals

- Prescribing agent behavior or embedding agent-specific instructions
- Embedding project-specific knowledge (file paths, tool versions)
- Defining state query implementations (consumers own these)

## Behavior

### Template Rendering

```gherkin
Given a command with a stdin template and context entries
When the command is executed
Then each context entry resolves its state query
And state results are injected into the template as {{ state.<name> }}
And the rendered template is piped to the run command
```

### Graceful Degradation

```gherkin
Given a template with {% if state.verify is defined %} guards
When the verify state query is not configured
Then the guarded section is omitted
And the template renders without error
```

### State Query Contract

```gherkin
Given a state query defined in graft.yaml
When the query executes
Then it produces a valid JSON object on stdout
```

### Edge Cases

- All state absent: template renders with only the output format section
- State query timeout: command fails with a clear error (not a partial render)
- State query returns invalid JSON: command fails before template rendering

## Constraints

- Templates must render without error when all state queries are absent
- Templates must not reference absolute paths or project-specific files
- Templates must reference AGENTS.md by name only (not by content)
- All state access must be `{% if %}` guarded
- State queries must produce JSON objects (not arrays or primitives)
- Template paths must be relative

## Open Questions

- [ ] State query JSON structure: `{raw: .}` wrapping vs structured fields -- currently consumers decide
- [ ] Template versioning mechanism for pinning across consumer updates
- [ ] Task injection: templates have no way to receive user-provided task descriptions; CLI args pass to `run:` command, not template context. Needs engine support for `{{ args }}` or similar. See [session note](../../../../notes/2026-02-21-plan-template-implementation.md).

## Decisions

- 2026-02-21: Output-schema focused templates -- templates inject state and define output format; skip generic instructions that duplicate agent capabilities
- 2026-02-21: Story + slices plan format -- plan output is a story-level frame with independently-testable vertical slices
- 2026-02-21: Spec ships with implementation -- specs that ship separately from code rot (per BDD evidence)

## Sources

- [Workflow design research](../../notes/2026-02-21-workflow-design-research.md) - Design principles and template conventions
- [Anthropic best practices](https://www.anthropic.com/engineering/claude-code-best-practices) - Verification criteria as highest-leverage practice
- [MAKER study](https://blog.continue.dev/task-decomposition/) - Task decomposition evidence
- [Fowler SDD analysis](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) - Anti-patterns in spec-driven development
