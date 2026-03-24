# .github — Organisation-wide defaults

This repository contains default community health files and templates that apply across **all repositories** in the organisation. If a repo doesn't have its own version of a file, GitHub will fall back to the version here.

## Contents

### `PULL_REQUEST_TEMPLATE.md`
The default PR description template. It is automatically pre-filled when a new pull request is opened in any repo in the organisation.

It prompts for:
- **Description** — key changes, refactoring, or bug fixes
- **References** — Jira tickets or related issues
- **Screenshots** — before/after visuals where relevant
- **Risks** — None / Low / Medium / High

---

## Related conventions

Individual repos should also include the following GitHub Actions workflows to enforce naming conventions. See `infolite-core` for reference implementations:

### Branch naming — `branch-name-check.yml`
Validates that branch names follow the format:
```
{name}/{intent}/{optional-JIRA-123-}summary
```
Examples:
- `rahmat/feat/HS-121-add-planned-outages`
- `john/spike/experiment-with-metrics`

### PR title — `pr-title-check.yml`
Validates that PR titles follow the format:
```
{intent}: [{JIRA-123}] summary          # with Jira ticket
{intent}: summary                        # without Jira ticket
```
Examples:
- `chore: [HS-169] remove local timezone and show AEMO timezone`
- `feat: add planned outages`

Valid intents: `feat` | `fix` | `chore` | `refactor` | `docs` | `spike`

---

## Adding workflows to a new repo

Copy the workflow files from `infolite-core/.github/workflows/` into the new repo's `.github/workflows/` directory, then enable branch protection rules in **Settings → Branches** to require the checks to pass before merging.
