# Auto-Review Fleet

Automated, scheduled code review by a fleet of narrow-scope Claude Code sub-agents. Findings surface as PRs (for auto-fixable changes) or issues (for human-reviewed reports).

---

## Architecture

```
Cloud Routine (cron, Anthropic console)
       │
       ▼
Claude Code sub-agent (`.claude/agents/<name>.md`)
       │  reads repo with Read / Grep / Glob / Edit
       ▼
Output: markdown report or file edits
       │
       ▼
Cloud Routine opens GitHub PR or issue with label `auto-review`
```

Two layers:

1. **In-repo (this directory + `.claude/agents/`).** Sub-agent system prompts, allowlist, and documentation. Versioned, reviewed by PR, owned by the team.
2. **Out-of-repo (Anthropic console).** Cloud Routines configured in the owner's Claude Code Cloud account. They schedule the sub-agents via the GitHub connector and open the PR/issue with the captured output. Not versioned — kept in sync manually via the replication guide below.

---

## The 6 sub-agents

| Agent | File | Scope | Mode | Output target |
| --- | --- | --- | --- | --- |
| `terraform-reviewer` | `.claude/agents/terraform-reviewer.md` | `infra/` | read-only | PR (report) |
| `python-reviewer` | `.claude/agents/python-reviewer.md` | `agents/*/src/`, `shared/src/` | auto-fix | PR (code edits) |
| `security-scanner` | `.claude/agents/security-scanner.md` | whole repo | read-only | Issue (report) |
| `docs-sync` | `.claude/agents/docs-sync.md` | `docs/`, `*.md` | auto-fix | PR (doc edits) |
| `dependency-updater` | `.claude/agents/dependency-updater.md` | `pyproject.toml`, `uv.lock`, `Dockerfile` | auto-fix | PR (version bumps) |
| `comment-minimalism-enforcer` | `.claude/agents/comment-minimalism-enforcer.md` | all source file types | auto-fix | PR (comment removals) |

Each sub-agent declares its tool access and model in the YAML frontmatter. Scope boundaries are strict — `python-reviewer` never touches Terraform, `docs-sync` never touches code, etc.

---

## Allowlist: `accepted-findings.md`

The fleet's memory layer. Without it, sub-agents regenerate the same findings on every run because they operate on a stateless snapshot of the repo.

Every sub-agent prompt includes a "Consult the allowlist first" preamble that instructs it to:

1. Read [`accepted-findings.md`](./accepted-findings.md) before emitting findings.
2. Match candidate findings against the relevant category table (file pattern + issue keywords).
3. Skip silently when a row matches and is not expired.
4. When re-surfacing despite a match (because the underlying code genuinely changed), include an explicit note referencing the entry ID.

### Adding an entry

Open a PR that appends a row to the right category table in `accepted-findings.md`. Requires:

- A concrete `Reason` — tenant constraint, MVP trade-off, false positive with technical explanation, or deferred to a specific later iteration.
- A `Ref` to the PR or issue where the triage decision was made.
- An `Expires` date if the acceptance is bounded (e.g., "until iter 2 lands", "until UCM grants AMPLS permissions", "until tflint actually flags the rule").
- One approval.

### Expiring an entry

Set the `Expires` column to the date after which the acceptance lapses. On the next scheduled run after that date, the sub-agent may re-surface the finding. If the re-surfacing is still unwanted, extend `Expires` via a new PR.

### Removing an entry permanently

If the code that produced the finding is gone or the acceptance is no longer valid, open a PR that deletes the row. The next run will surface the finding again if the underlying condition is back.

### Re-surfacing rules

A sub-agent may re-surface a finding that matches an accepted entry **only** if the underlying code has materially changed since the acceptance `Date`. The re-surface must include an explicit note in the agent's output: `"Re-surfacing despite accepted entry <ID> because <concrete change>"`. The PR reviewer decides whether to accept the re-surface or update the allowlist entry.

---

## Kill switch

To stop a sub-agent from running: disable the corresponding **Cloud Routine** in the Anthropic console. The agent prompt file stays in-repo. Re-enable by toggling the Routine back on.

To stop the whole fleet: disable all six Cloud Routines. The in-repo files are inert without a Routine to invoke them.

---

## Cost budget

Approximate monthly API cost at the current cron cadence (daily for `terraform`, `python`, `security`, `docs-sync`; weekly for `dependency-updater` and `comment-minimalism-enforcer`), using `sonnet` for most agents and `haiku` for `comment-minimalism-enforcer`:

- Per-run cost: $0.15–$0.60 depending on the agent's tool budget (`maxTurns: 8` caps worst case)
- Monthly total: ~$48 (tracked in the owner's Anthropic billing console)

Set a monthly spend cap on `ANTHROPIC_API_KEY` to enforce the budget.

---

## Replication guide (for teammates who want to run their own Routines)

The sub-agents in `.claude/agents/` are plain Claude Code sub-agents — anyone on the team can invoke them from their own Claude Code Cloud account. To replicate the scheduled fleet:

1. Clone the repo into a Claude Code Cloud workspace with the GitHub connector authorized.
2. Create one Cloud Routine per sub-agent. For each:
   - **Schedule.** Match the cadence in the table above (daily for high-churn agents, weekly for low-churn).
   - **Task prompt.** Reference the sub-agent by name: `Invoke the <name> sub-agent against the repository`. Claude Code loads the frontmatter + prompt automatically.
   - **Repository access.** Grant read access to the full repo; grant write access only to agents that auto-fix (see the "Mode" column).
   - **Output action.** Capture the agent's final text block and open a PR (or issue for `security-scanner`) with the `auto-review` label. Title convention: `chore(auto-review/<category>): <one-line summary>`.
3. Before enabling, run the Routine manually once and triage the output. Adjust the sub-agent prompt if the output shape is wrong.
4. Set a per-key budget cap in the Anthropic console.

Teammates running their own Routines should **not** commit additional copies of the sub-agent prompts — there is a single source of truth under `.claude/agents/`. Improvements to the prompts are PRs against this repo.

---

## History

- 2026-04-22 — [PR #42 / TFM-58](https://github.com/cgaravitoq/master-26-tfm/pull/42) introduced the fleet (6 sub-agents, Cloud Routines in the owner's account). The `docs/auto-review.md` promised in that PR was never committed.
- 2026-04-23 — First run surfaced real findings: triaged into TFM-59 (`opencode` action pin), TFM-60 (least-privilege RBAC, regional OpenAI SKU), TFM-61 (API key middleware), plus backlog issues TFM-62/63/64/65.
- 2026-04-24 — Recurrence detected: PR #52 was byte-identical to the already-closed PR #44; PR #51 and Issue #53 repeated findings triaged 24 hours earlier. Triggered [TFM-67](https://linear.app/master-26-tfm/issue/TFM-67) — this allowlist + preamble work.
