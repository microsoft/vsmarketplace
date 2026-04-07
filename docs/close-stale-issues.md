# Close stale issues workflow

This workflow script is located at `../.github/workflows/close-stale-issues.yaml` and runs daily (and on manual dispatch) to find and close GitHub issues that have had no customer (non-authorized) comments within a configured lookback window.

Summary
- Purpose: automatically comment on and close issues that have not received any non-authorized-user comments within the last 548 days.
- Trigger: daily schedule (`0 0 * * *`, midnight UTC) and `workflow_dispatch` for manual runs.
- Runner: `ubuntu-latest`.

How it works
- The job lists open issues and filters those created on or before the cutoff date (computed from `LOOKBACK_DAYS`, default 548).
- Issues are excluded if they carry any skip labels (e.g. `Priority:0`, `Priority:1`, `Type:Feature`, `DoNotClose`).
- For each candidate issue, the workflow fetches issue comments since the cutoff and counts only comments from users not in the authorized users list (`AUTH_USERS`).
- If there are no such customer comments, the workflow posts a staleness comment and closes the issue.

Configuration / customization
- `LOOKBACK_DAYS`: number of days to look back for comments (default 548).
- `AUTH_USERS`: space-separated list of usernames whose comments are ignored (bots and internal reviewers).
- `SKIP_LABELS`: array in the script holds labels that prevent automatic closing.
- `REPO`: repository owner/name is set in the workflow environment.
- To change frequency, edit the cron expression under `on.schedule` in the YAML.

Permissions / requirements
- The job requires `issues: write` permission (configured in the YAML) and uses the `GITHUB_TOKEN` for API calls via the `gh` CLI.
- The workflow relies on the `gh` CLI and `jq` available in the runner image.

Notes
- The staleness comment text and close behavior are implemented in the workflow script itself; review the YAML for exact wording and behavior.
- If you want a different policy (e.g., add a reopen window or label instead of closing), edit the script logic or add an intermediate label step.

See also
- Workflow file: [.github/workflows/close-stale-issues.yaml](.github/workflows/close-stale-issues.yaml)
