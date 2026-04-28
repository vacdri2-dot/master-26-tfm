---
name: commit-push-pr
description: >
  Commit staged changes, push a branch, and create a GitHub pull request
  following this project's conventions. Use when the user asks to commit,
  push, create a PR, ship changes, send for review, or any combination of
  these — even if they say it casually like "ship it" or "send the PR."
  Also use when reviewing your own work before delivering it.
compatibility: Requires git and gh CLI. Designed for projects using AGENTS.md conventions.
metadata:
  author: tfm-team
  version: "1.1"
---

# Commit, Push & Pull Request

Follow these steps in order. Stop at whatever the user asked for (commit only, commit+push, or the full flow through PR creation).

## Step 1 — Branch

Verify you are on a correctly named branch:

- `feature/<slug>` for new work
- `fix/<slug>` for bug fixes
- Never commit directly on `main` or `staging`

If on the wrong branch, create one: `git checkout -b feature/tfm-<number>-<short-slug>`.

## Step 2 — Commit

### Choose the prefix

| Prefix | Use when |
|--------|----------|
| `feat:` | New feature or capability |
| `fix:` | Bug fix |
| `infra:` | Terraform, Azure, infrastructure |
| `docs:` | Documentation only |
| `refactor:` | Restructuring, no behavior change |
| `test:` | Tests only |
| `chore:` | Tooling, CI, config, dependencies |

### Write the message

```
<prefix> <imperative summary, max 72 chars>

- Key change 1
- Key change 2

Resolves: TFM-<number>
```

Rules:
- Imperative mood ("add", "fix", "configure" — not "added", "fixes")
- All English
- Include `Resolves: TFM-XX` when a Linear issue is linked

### Squash to one commit

If the branch has multiple commits, squash before pushing:

```bash
git reset --soft $(git merge-base origin/staging HEAD)
git commit -m "<message>"
```

Never leave "wip", "fix typo", or "address review comments" commits.

## Step 3 — Push

```bash
git fetch origin && git rebase origin/staging
git push -u origin <branch-name>
```

If history was rewritten (squash/rebase), use `--force-with-lease` (never bare `--force`).

## Step 4 — Create PR

### Fetch Linear context

If a TFM issue is linked, fetch it to get title, description, and parent for context. Use the branch name to infer the issue number (e.g., `feature/tfm-16-...` → `TFM-16`).

### Title

Must match conventional commit format — usually identical to the commit summary:

```
infra: configure Terraform remote backend on Azure Storage
```

### Body

Read the template from [references/pr-body-template.md](references/pr-body-template.md) and fill it in. Do not leave placeholder text.

### Create

```bash
gh pr create \
  --base staging \
  --title "<title>" \
  --body "$(cat <<'EOF'
<filled template>
EOF
)"
```

Base is always `staging`. Return the PR URL to the user when done.

## Gotchas

- **GitHub auto-generates bad titles** from branch names (e.g., `Feature/tfm 16 configurar...`). Always set the title explicitly with `--title`.
- **Merge commits break linear history.** If `git log --oneline` shows any merge commits on the branch, squash them out before pushing.
- **The OpenCode review bot** will comment on the PR. It is review-only and should never commit or push. If it flags issues, fix them with amend + force-push (never add "fix review" commits).
- **`infra/environments/*/backend.hcl`** is git-ignored (auto-generated). Never commit it.
- **`.terraform.lock.hcl`** IS tracked. Do not add it to `.gitignore`.

## Error handling

| Situation | Action |
|-----------|--------|
| On `main` or `staging` | Create a feature branch first, ask for issue ID |
| No Linear issue | Ask the user which issue this relates to |
| Push rejected | `git pull --rebase origin staging`, resolve conflicts, retry |
| PR already exists | Update existing PR, do not create a duplicate |
