---
status: draft
created: 2026-02-22
---

# Capture Claude Code session IDs from implement runs and add a resume command

## Story

When `graft run implement` invokes Claude Code, the session ID is lost — there's no way to resume if the work is interrupted or to continue with the next step in the same conversational context. This slice captures the session ID from each implement run and adds a `resume` command so agents can pick up where they left off.

## Approach

Replace the inline pipeline in the `implement` command with a wrapper script (`scripts/implement.sh`) that runs `claude -p --output-format json`, extracts the `session_id` from the JSON response, saves it to `slices/<slug>/.session`, and prints the text result. A new `scripts/resume.sh` reads the stored session ID and launches `claude --resume <id>` for interactive continuation. Both commands are wired in `graft.yaml` alongside the existing `iterate` and `implement` entries.

Session files live in the consumer's slice directory (e.g. `slices/my-feature/.session`) — zero infrastructure, naturally scoped per-slice, and gitignored since session IDs are machine-specific.

## Acceptance Criteria

- `graft run implement <slice>` produces the same visible output as before (claude's response text), but also writes `slices/<slug>/.session` containing the session ID
- `graft run resume <slice>` launches an interactive Claude Code session that resumes the last implement session for that slice
- `graft run resume` on a slice with no stored session prints a clear error
- `.session` files are gitignored (not committed)
- Existing `iterate` command is unchanged

## Steps

- [ ] **Create `scripts/implement.sh` wrapper**
  - **Delivers** — implement command captures session IDs while preserving user-visible output
  - **Done when** — running `bash scripts/implement.sh <slug>` pipes iterate output to claude with `--output-format json`, extracts and saves `session_id` to `slices/<slug>/.session`, prints the text result to stdout; errors from claude are surfaced to stderr
  - **Files** — `scripts/implement.sh`

- [ ] **Create `scripts/resume.sh`**
  - **Delivers** — users can resume an interrupted Claude Code session for any slice
  - **Done when** — `bash scripts/resume.sh <slug>` reads `slices/<slug>/.session`, launches `claude --resume <id> --dangerously-skip-permissions`; missing `.session` file produces a clear error message; accepts optional extra args passed through to claude
  - **Files** — `scripts/resume.sh`

- [ ] **Wire commands in `graft.yaml` and gitignore `.session` files**
  - **Delivers** — `graft run implement` and `graft run resume` work end-to-end
  - **Done when** — `implement` command uses `scripts/implement.sh` instead of inline pipeline; `resume` command added with `slice` arg using `options_from: slices`; `slices/**/.session` added to `.gitignore`
  - **Files** — `graft.yaml`, `.gitignore`
