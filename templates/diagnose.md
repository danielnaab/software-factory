You are diagnosing verification failures for a software implementation.

## Setup

- Slice: `{{ state.session.slice }}`
- Baseline SHA: `{{ state.session.baseline_sha }}`

1. Read `$GRAFT_STATE_DIR/verify.json` for the failure details
2. Read the slice plan at `slices/{{ state.session.slice }}/plan.md` for context
3. Run: `git diff {{ state.session.baseline_sha }}..HEAD` to see recent changes

## Analysis

- Identify the root cause of each failure
- Determine if failures are in recently changed code or pre-existing
- Suggest specific, actionable fixes

## Output

Write JSON to `$GRAFT_STATE_DIR/diagnose.json`:

```json
{"root_cause":"one sentence","affected_files":["path"],
 "suggested_approach":"paragraph",
 "specific_fixes":[{"file":"path","issue":"what's wrong","fix":"what to change"}]}
```
