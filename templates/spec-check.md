You are checking implementation coverage against acceptance criteria.

## Setup

- Slice: `{{ state.session.slice }}`
- Baseline SHA: `{{ state.session.baseline_sha }}`

1. Read the slice plan at `slices/{{ state.session.slice }}/plan.md` — extract acceptance criteria
2. Run: `git diff {{ state.session.baseline_sha }}..HEAD` to see all changes

## Coverage Check

For each criterion:
- **covered**: clear evidence in the diff
- **uncovered**: no evidence found
- **not_diffable**: runtime behavior, not verifiable from diff

## Output

Write JSON to `$GRAFT_STATE_DIR/spec-check.json`:

```json
{"overall":"covered|partial|uncovered","uncovered_count":N,
 "criteria":[{"text":"criterion","coverage":"covered|uncovered|not_diffable",
              "evidence":"one-line note","note":""}]}
```

- "covered" overall = all criteria are covered or not_diffable
- "partial" = some uncovered
- "uncovered" = majority lack evidence
