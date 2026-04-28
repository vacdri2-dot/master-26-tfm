# PR Body Template

Use this template when creating a pull request. Fill in every section — do not leave placeholders.

```markdown
## Summary

<1-3 sentences: what this PR does and why>

## Changes

- <bullet per logical change>

## Checklist

- [x/space] Title follows conventional commit format
- [x/space] Single logical commit, rebased onto `staging`
- [x/space] All content in English
- [x/space] All files end with a trailing newline
- [x/space] No secrets or credentials in code
- [x/space] `terraform fmt` ran (if Terraform changes)
- [x/space] Tests pass locally (if applicable)
```

## Guidelines

- **Summary**: reference the Linear issue context, not just the title. Explain the "why."
- **Changes**: one bullet per logical change. Group related file changes into a single bullet.
- **Checklist**: mark `[x]` only for items you actually verified. Leave `[ ]` for items you could not check (e.g., no terraform installed locally).
