---
status: working
purpose: "Session note: workflow design research for software-factory templates and phases"
---

# Workflow Design Research

Research session exploring how software-factory should structure agent workflow templates. Covers evidence from existing tools, design principles derived from first principles, template system conventions, and the consumer wiring pattern.

## Three Workflow Phases

Research across 10+ tools and frameworks converged on three reusable phases: **Plan**, **Review**, and **Iterate**. Each is independent and composable -- use one, two, or all three.

### Plan -- Task Decomposition

**Purpose**: Decompose a task into verifiable increments before writing code.

**When to use**: Tasks touching >2 files, unclear scope, multiple valid approaches.
**When to skip**: Single-line fixes, trivial changes with obvious implementation.

**Evidence (strong)**:

- MAKER study: zero-error completion of 1,048,575 dependent steps on the 20-disk Tower of Hanoi using maximal decomposition. Cost grows as `s * log(s)` vs. exponentially with multi-step agents. Sources: [Continue.dev](https://blog.continue.dev/task-decomposition/), [Amazon Science](https://www.amazon.science/blog/how-task-decomposition-and-smaller-llms-can-make-ai-more-affordable)
- Copilot Workspace: most praised feature is its editable plan step. Source: [GitHub Next](https://githubnext.com/projects/copilot-workspace)
- Universal adoption: Spec-Kit tasks/, PAW, Ralph Loop, Cursor tasks, Devin chunking

### Review -- Post-Implementation Critique

**Purpose**: Evaluate changes against project conventions and verification criteria.

**When to use**: After implementation, before committing/merging.
**When to skip**: Trivial changes already verified.

**Evidence (strong)**:

- Anthropic engineering: "Giving Claude verification criteria is the single highest-leverage practice." Source: [Anthropic Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- Devin Critic model: dedicated adversarial review model. Sources: [Devin Agents 101](https://devin.ai/agents101), [Deep Dive into Devin 2.0](https://medium.com/@takafumi.endo/agent-native-development-a-deep-dive-into-devin-2-0s-technical-design-3451587d23c0)
- Monday.com: prevented 800+ issues/month with structured AI review. Source: [ThoughtWorks SDD](https://www.thoughtworks.com/en-us/insights/blog/agile-engineering-practices/spec-driven-development-unpacking-2025-new-engineering-practices)
- 33k-PR study: CI failures account for 17% of agent PR rejections. Source: [arxiv 2601.15195](https://arxiv.org/abs/2601.15195)

### Iterate -- Autonomous Work Loop

**Purpose**: Autonomous loop: implement -> verify -> self-critique -> fix.

**When to use**: Multi-step tasks where the agent should work autonomously.
**When to skip**: Simple tasks completable in one shot.

**Evidence (medium)**:

- Ralph Loop: already working across 4 instances in graft (process-management, rust-rewrite, workspace-unification, command-prompt-view-stack)
- SWE-Agent/Devin: both use the ReAct loop (Observe -> Think/Plan -> Act -> Observe result -> repeat). Sources: [OpenHands ICLR](https://arxiv.org/abs/2407.16741), [SWE-Agent NeurIPS](https://proceedings.neurips.cc/paper_files/paper/2024/file/5a7c947568c1b1328ccc5230172e1e7c-Paper-Conference.pdf)
- Anthropic two-agent pattern: initializer + coding agent with `claude-progress.txt` as cross-session memory. Source: [Anthropic Harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- Frequent small commits as memory: recommended 4x more frequently than traditional development

### Cross-Phase Evidence Summary

| Finding | Strength | Implication |
|---------|----------|-------------|
| Task decomposition is the most reliably beneficial practice | Strong (MAKER: zero errors across 1M+ steps) | Formalize a planning step |
| Verification criteria are the highest-leverage quality lever | Strong (Anthropic, multiple frameworks) | Formalize a verify step |
| Self-critique improves output quality | Medium (Devin Critic, Ralph Loop step 7) | Formalize a review step |
| Frequent small commits serve as memory across context windows | Strong (Anthropic harness, Ralph Loop) | Formalize commit checkpoints |
| Session handoff artifacts prevent context loss | Medium (Anthropic initializer/coder pattern) | Formalize a handoff convention |
| Over-specification for small tasks is counterproductive | Strong (Fowler SDD critique) | Templates must be proportional |
| Specs that aren't maintained drift and mislead | Medium (ThoughtWorks, this project's own experience) | Formalize a spec-sync check |

## Anti-Patterns NOT to Formalize

Explicitly rejected based on evidence:

- **Exhaustive spec generation before code**: Fowler found Kiro turning a bug fix into 4 user stories with 16 acceptance criteria. Source: [Fowler SDD analysis](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
- **`generate-docs` command**: auto-generated docs harder to review than code
- **`auto-implement` (unbounded loop)**: evidence shows exponential cost growth and 1.7x bug rate. Source: [Stack Overflow](https://stackoverflow.blog/2026/01/28/are-bugs-and-incidents-inevitable-with-ai-coding-agents/)
- **Verbose spec review replacing code review**: Spec-kit generated 8+ markdown files per specification
- **Assumption that specs prevent drift**: Fowler notes SDD "encodes the assumption that you aren't going to learn anything during implementation"
- **Abstraction bloat from agents**: agents scaffold 1,000 lines where 100 would suffice. Source: [Addy Osmani - 80% Problem](https://addyo.substack.com/p/the-80-problem-in-agentic-coding)

## Design Principles

Eight principles derived from meta-KB foundations and the evidence above:

1. **Context is the product** -- The primary value software-factory provides is assembling the right information at the right time. Agent output quality is bounded by context quality.

2. **Structure not substance** -- Templates define workflow structure (what context slots exist, what steps to follow). Consumers provide project-specific content via state queries and AGENTS.md. This is dependency injection applied to workflow prompts.

3. **Graceful degradation** -- Templates work with or without optional state data. All state access uses `{% if %}` guards. No state query is required.

4. **Agent-agnostic** -- Templates produce structured text. They don't assume a specific AI model, tool, or invocation method. The consumer's `run:` command determines what receives the prompt.

5. **Verification anchors every phase** -- Every workflow phase references verification as a gate. Unverified output is noise.

6. **Knowledge through grafting** -- Project conventions come from AGENTS.md (per meta-KB patterns). Templates never embed project-specific knowledge -- they reference AGENTS.md by name only.

7. **Composable phases** -- Workflow phases are independent. Use one, two, or all three.

8. **Proportional ceremony** -- A one-line fix doesn't need a plan. Templates include guidance on when to scale up vs. skip.

**Additional design insight**: Templates are lean -- they tell agents what to READ (pointing to AGENTS.md), not embedding file contents. This works because agents have tool access even in batch mode (`claude --dangerously-skip-permissions --print`).

## Template System Conventions

### Built-in Variables (from `crates/graft-engine/src/template.rs`)

```
{{ repo_name }}    -- repository basename
{{ repo_path }}    -- full repository path
{{ git_branch }}   -- current branch name
{{ commit_hash }}  -- current git commit hash
```

### State Variables

```
{{ state.<query_name> }}    -- resolved state query results
```

### Graceful Degradation with Guards

All state access MUST be guarded:

```jinja2
{% if state.verify is defined %}
## Current Verification Status

{{ state.verify }}
{% endif %}
```

### State Query Naming Conventions

Templates reference these by convention; consumers define the actual commands:

| Name | Purpose | Example consumer command |
|------|---------|------------------------|
| `verify` | Verification results (tests, lint, format) | `cargo fmt --check && cargo clippy && cargo test` |
| `changes` | Recent changes (diff, commit log) | `git log --oneline -10; git diff --stat` |
| `tasks` | Task tracking state (plan, progress) | Consumer-specific |

### Template Structure Convention

Each template follows: Role (one-line identity) -> Context (guarded state) -> Instructions (phase-specific steps) -> Reference (pointer to AGENTS.md).

### Template Engines

Two engines in graft: `tera` (default, Jinja2-compatible) and `none` (raw, no rendering).

### Template Constraints

- Must render without error when all state queries are absent
- Must not reference absolute paths or project-specific file names
- Must reference AGENTS.md by name only (not by content)

## Consumer Wiring Pattern

The composition model is dependency injection for workflows:

```
software-factory provides: TEMPLATES (structure, slots)
consumer provides:         STATE QUERIES (substance, language-specific commands)
consumer provides:         COMMANDS (wiring templates to state queries to execution)
```

### Example Consumer graft.yaml

```yaml
apiVersion: graft/v0

commands:
  plan:
    run: "cat"
    description: "Render the planning prompt with current project state"
    stdin:
      file: .graft/software-factory/templates/plan.md
    context:
      - verify

  review:
    run: "cat"
    description: "Render the review prompt with changes and verification"
    stdin:
      file: .graft/software-factory/templates/review.md
    context:
      - verify
      - changes

  iterate:
    run: "cat"
    description: "Render the iteration prompt with task and verification state"
    stdin:
      file: .graft/software-factory/templates/iterate.md
    context:
      - verify

state:
  verify:
    run: "bash -c 'echo \"## Format\"; cargo fmt --check 2>&1 | tail -5; echo; echo \"## Lint\"; cargo clippy -- -D warnings 2>&1 | tail -10; echo; echo \"## Tests\"; cargo test 2>&1 | tail -5'"
    cache:
      deterministic: true
    timeout: 120

  changes:
    run: "bash -c 'echo \"## Recent Commits\"; git log --oneline -10; echo; echo \"## Uncommitted Changes\"; git diff --stat'"
    cache:
      deterministic: true
    timeout: 30
```

### Execution Flow

1. For each `context` entry: look up state query, execute (with caching), store result
2. Merge state results into template context
3. If `stdin` present: render Tera template with state + built-in variables
4. Execute `run` command with rendered template piped to stdin
5. Return exit code, stdout, stderr

### `run: "cat"` Design Decision

Using `cat` keeps the system agent-agnostic -- `graft run plan` outputs the rendered prompt to stdout. Users decide where to send it:

- `graft run plan` -- print to terminal
- `graft run plan --dry-run` -- preview without executing
- `graft run plan | claude --print -` -- pipe to AI
- `graft run plan | pbcopy` -- clipboard

## Relationship to Meta-KB and Living-Specifications

### Authority Model (code > specs > docs > notes)

- Templates are canonical deliverables (like code)
- Specifications define the contracts (like specs)
- Principles document design philosophy (like docs)
- Session notes are ephemeral (like notes)

### Temporal Layers

- **Durable**: `docs/principles.md`, `docs/specifications/*.md`, `templates/*.md`
- **Tracking**: AGENTS.md, knowledge-base.yaml
- **Ephemeral**: `notes/` (session logs, exploration)

### Living-Specifications Format

Specs should use this frontmatter and structure:

```yaml
---
status: draft | working | stable | deprecated
last-verified: YYYY-MM-DD
owners: [team-members]
---
```

Core sections: Intent, Non-goals, Behavior (Given/When/Then), Constraints, Open Questions, Decisions, Sources.

### Knowledge Through Grafting

Software-factory declares its own dependencies:

```yaml
deps:
  meta-knowledge-base: "https://github.com/danielnaab/meta-knowledge-base.git#main"
  living-specifications: "https://github.com/danielnaab/living-specifications.git#main"
```

## Template Drafts

Full template content for each phase, ready for extraction into `templates/` when implementing that vertical slice.

### templates/plan.md

```jinja2
You are a software development agent planning an implementation task.

{% if state.verify is defined %}
## Current Verification Status

{{ state.verify }}
{% endif %}

## Instructions

1. Read `AGENTS.md` for project conventions, verification commands, and write boundaries
2. Understand the task: what is being asked, and why
3. Explore the codebase to find relevant files, existing patterns, and reusable utilities
4. Identify the minimal set of changes needed -- prefer editing existing files over creating new ones
5. Produce a plan as an ordered list of increments

For each increment:
- **What**: one-sentence description of the change
- **Files**: specific files to modify or create
- **Acceptance criteria**: how to verify this increment is correct
- **Dependencies**: which earlier increments must complete first

## Guidance

- If the task is trivial (single file, obvious change), skip planning and just implement it
- Prefer increments that leave the codebase in a working state (all checks passing)
- Each increment should be independently verifiable
- Reference existing patterns in the codebase rather than inventing new ones
```

### templates/review.md

```jinja2
You are a software development agent reviewing recent changes.

{% if state.changes is defined %}
## Recent Changes

{{ state.changes }}
{% endif %}

{% if state.verify is defined %}
## Verification Status

{{ state.verify }}
{% endif %}

## Instructions

1. Read `AGENTS.md` for project conventions and verification commands
2. Review the changes shown above (or run `git diff` if no changes are provided)
3. Evaluate each change against these criteria:

### Correctness
- Does the code do what it claims to do?
- Are edge cases handled?
- Are error messages helpful?

### Conventions
- Does it follow the patterns established in AGENTS.md?
- Are naming conventions consistent with the rest of the codebase?
- Are write boundaries respected?

### Verification
- Do all existing tests still pass?
- Are new behaviors covered by tests?
- Is the verification command green?

### Simplicity
- Is there unnecessary complexity?
- Are there abstractions for single-use cases?
- Could any change be smaller while achieving the same goal?

## Output

For each issue found:
- **Severity**: high (must fix) / medium (should fix) / low (optional)
- **Location**: file and line
- **Issue**: what's wrong
- **Fix**: specific recommendation
```

### templates/iterate.md

```jinja2
You are an autonomous software development agent working through a task iteratively.
Each cycle: implement, verify, self-critique, fix.

{% if state.verify is defined %}
## Current Verification Status

{{ state.verify }}
{% endif %}

{% if state.tasks is defined %}
## Task State

{{ state.tasks }}
{% endif %}

## Instructions

### 1. Orient
- Read `AGENTS.md` for project conventions and verification commands
- Understand the current state: what has been done, what remains
- If task state is provided above, find the next uncompleted item
- If no task state is provided, work from the task description given to you

### 2. Implement
- Make the smallest change that moves toward the goal
- Follow existing patterns in the codebase
- Prefer editing existing files over creating new ones

### 3. Verify
- Run the project's verification commands (from AGENTS.md)
- If verification fails, fix the issues before proceeding
- Do not skip verification or mark a task complete with failing checks

### 4. Self-Critique
After verification passes, review what you just built:
- Re-read the acceptance criteria. Are they genuinely met?
- Are the public interfaces well-named and ergonomic?
- Are errors propagated with enough context?
- Are tests thorough (happy path, errors, edge cases)?

### 5. Fix
If critique found concrete issues (not style nitpicks), fix them now. Run verification again.

### 6. Commit
Commit the working, verified implementation. Use descriptive commit messages.

## Guidance

- Each iteration should leave the codebase in a passing state
- If a task is too large for one pass, complete a meaningful subset and note what remains
- If you are stuck, describe the blocker rather than guessing
```

## Proposed Files for Vertical Slices

Each row is a candidate slice, implementable independently:

| File | Description |
|------|-------------|
| `docs/principles.md` | Design philosophy (8 principles above) |
| `docs/specifications/prompt-templates.md` | Template system spec (living-specs format) |
| `docs/specifications/workflow-phases.md` | Workflow phases spec (living-specs format) |
| `templates/plan.md` | Plan phase Tera template |
| `templates/review.md` | Review phase Tera template |
| `templates/iterate.md` | Iterate phase Tera template |
| `knowledge-base.yaml` | Add `templates/**` to sources and write rules |
| `AGENTS.md` | Reference new docs and templates |
| Consumer `graft.yaml` (repo root) | Add commands + state queries for dogfooding |

## Open Questions

1. **State query JSON structure** -- Simple `jq -Rs '{raw: .}'` wrapping vs. structured JSON with specific fields. Templates need `state.verify` to exist (for conditionals) but the internal structure is up to consumers.

2. **Template versioning** -- Consumers should be able to pin template versions. New versions can add optional context slots without breaking existing consumers. Mechanism not yet specified.

3. **Iterate as single vs. composed template** -- Decision: keep as single template. The autonomous loop context requires all steps in a single prompt.

4. **Level of prescription** -- Templates should provide structure and decision points but stay abstract about implementation details.

5. **Generic loop script** -- The iterate template is essential; a generic `ralph.sh`-style loop script could live in `scripts/` but is not a template.

6. **Batch vs. interactive mode** -- Templates should work in both. Since batch mode (`claude --print`) is the harder constraint, design for that first.

## Surveyed Tools

For reference, the tools and frameworks examined during this research:

- Copilot Workspace (GitHub Next)
- Devin (Cognition)
- SWE-Agent / OpenHands
- Cursor (plan mode + tasks)
- Claude Code (Anthropic two-agent pattern)
- GitHub Spec-Kit
- AWS AI-DLC
- Phased Agent Workflow (PAW)
- Gene Kim's Three Loops framework
- Ralph Loop (graft-internal)
- Martin Fowler's SDD analysis
- Kiro (AWS)
