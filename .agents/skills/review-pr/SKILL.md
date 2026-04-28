---
name: review-pr
description: >
  Review code review comments left by OpenCode (or any reviewer) on a PR
  and triage each one: fix it, or dismiss it as a false positive with a reason.
  Use when the user asks to "check the review", "address comments", "handle
  the code review", "triage the PR feedback", "review-pr", or similar.
compatibility: Requires gh CLI authenticated with repo access.
metadata:
  author: tfm-team
  version: "1.0"
---

# Review Comments Triage

Fetch review comments from a PR, analyze each one, and take action.

## Step 1 — Identify the PR

Determine the PR number:
- If the user provides it, use that
- Otherwise, infer from the current branch: `gh pr view --json number --jq .number`

## Step 2 — Fetch comments

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --jq '.[].body'
```

Also check for inline review comments:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[] | "**" + .path + ":" + (.line // .original_line | tostring) + "** — " + .body'
```

## Step 3 — Triage each finding

For each issue raised in the review, classify it:

| Classification | Criteria | Action |
|----------------|----------|--------|
| **Valid fix** | The reviewer is right, the code/config has a real problem | Fix it |
| **False positive** | The reviewer is wrong or the issue no longer applies | Explain why to the user, skip it |
| **Already fixed** | Was valid but a subsequent commit already addressed it | Note it, skip it |
| **Out of scope** | Valid concern but belongs in a different PR/issue | Note it for later, skip it |

### For each finding, present to the user:

```
[FINDING]: <one-line summary of what the reviewer flagged>
[CLASSIFICATION]: Valid fix | False positive | Already fixed | Out of scope
[REASON]: <why you classified it this way>
[ACTION]: <what you will do — fix description, or why you're skipping>
```

## Step 4 — Wait for user confirmation

Present ALL findings with their classifications before making any changes.
Wait for the user to confirm or override any classification.
Do NOT start fixing code until the user approves the triage.

## Step 5 — Apply fixes

For each item the user confirmed as "Valid fix":
1. Make the code change
2. Stage the changed files

Do NOT commit yet — let the user decide how to commit (they may want to use the `commit-push-pr` skill or amend).

## Rules

- Never dismiss a "Must Fix" without a concrete reason
- If the reviewer flags something that was already fixed in a later commit, check the current state of the file before classifying
- If unsure whether something is a false positive, default to "Valid fix"
- Keep the triage concise — one line per classification, not paragraphs
- The OpenCode bot review comment always ends with a `[github run]` link — ignore that line
- Missing Linear issue reference is only a valid finding if the PR branch originates from a Linear issue (e.g., branch name contains `tfm-XX`). PRs created outside the Linear workflow do not need a `Resolves: TFM-XX` — classify as false positive
