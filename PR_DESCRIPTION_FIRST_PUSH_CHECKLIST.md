# PR Description on First Push Checklist

Use this checklist to set up PR description auto-population exactly once (on PR creation), while keeping manual edits safe.

## Goal

- [ ] PR description is auto-populated when the PR is first opened.
- [ ] PR description is not auto-overwritten on later pushes.
- [ ] Team can still manually edit the PR description at any time.

## 1) Confirm your baseline

- [x] A standard template exists in [PULL_REQUEST_TEMPLATE.md](PULL_REQUEST_TEMPLATE.md).
- [x] Required sections are clear (Description, References, Screenshots, Risks).
- [x] The template works across repos where org defaults are expected.

## 2) Define first-push-only trigger behavior

- [x] Workflow trigger is `pull_request` with `types: [opened]` only.
- [x] `synchronize` is not used for body generation.
- [x] Manual trigger exists with `workflow_dispatch` for operator-driven reruns.
- [ ] Optional: include `reopened` only if you want regeneration on reopen.

## 3) Add safe write conditions

- [x] Update PR body only when it is empty or still template-only.
- [x] Never overwrite if the user already edited the body.
- [x] Add a marker line (for example: `<!-- pr-body-generated -->`) to identify bot output.

## 4) Decide generation source

- [x] Source inputs are deterministic (PR title, changed files, commit messages, diff stats).
- [x] Jira key is extracted from branch name first (fallback to PR title).
- [x] Section mapping is stable (for example, infer risks from touched infrastructure/security files).
- [x] Output format matches template headings exactly.

## 5) Set permissions and security

- [x] Workflow has minimum required permissions: `pull-requests: write`.
- [x] Use `GITHUB_TOKEN`; avoid extra PATs unless required.
- [ ] For fork PRs, confirm expected behavior and token limitations.

## 6) Protect manual edits

- [x] Job exits early if marker exists and body has non-template content.
- [ ] Add a documented opt-in override (label or slash command) if regeneration is needed.
- [x] Make "first write wins" the default policy.

## 7) Validate in test scenarios

- [ ] New PR with empty body gets generated content.
- [ ] New PR with manual body is left untouched.
- [ ] Subsequent commits do not modify body.
- [ ] Reopen behavior matches your policy.
- [ ] Label/override regeneration works (if implemented).

## 8) Rollout and documentation

- [x] Add workflow to this repo, then roll out to target repos.
- [x] Ensure runnable workflow exists in `.github/workflows/` path.
- [x] Document behavior in [README.md](README.md).
- [ ] Share team guidance: when to trust generated text and when to edit manually.

## 9) Troubleshooting notes

- [x] Confirmed: workflows do not run when stored outside `.github/workflows/`.
- [x] Confirmed: `workflow_dispatch` "Run workflow" appears only after the workflow exists on the default branch.

## Suggested policy (quick default)

- [x] Generate only on PR opened.
- [x] Skip when body is non-empty.
- [x] Insert marker comment after generation.
- [x] Never rewrite automatically after initial generation.