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

### Auto-tagging — `auto-tag.yml`
Automatically creates a git tag on merges to the default branch based on the PR title intent:
- `feat` → bumps minor version
- `fix` → bumps patch version
- `chore` / `refactor` / `docs` / `spike` → no tag

---

## Adding workflows to all repos — `rollout-workflows.sh`

The `rollout-workflows.sh` script automates rolling out the three workflow files (`branch-name-check.yml`, `pr-title-check.yml`, `auto-tag.yml`) to every repo in the organisation by opening a PR in each one.

### Requirements

- [`gh` CLI](https://cli.github.com/) installed and authenticated (`brew install gh` then `gh auth login`)
- Run from the root of this repo (so the script can find the workflow source files alongside it)

### Usage

**Preview first (recommended):**
```sh
./rollout-workflows.sh --dry-run
```
Clones every repo and checks which ones are missing the workflows. Prints a list of repos that *would* get a PR opened — no git push, no PRs created.

**Live run:**
```sh
./rollout-workflows.sh
```
For each repo that doesn't already have all three workflow files, the script:
1. Clones the repo (shallow)
2. Creates branch `chore/add-naming-convention-workflows`
3. Copies the three workflow files into `.github/workflows/`
4. Commits, pushes, and opens a PR

Repos that already have all three files are skipped automatically. `infolite-core` and `.github` itself are always excluded.

**Target a single repo (dry-run or live):**
```sh
./rollout-workflows.sh --repo my-repo-name
./rollout-workflows.sh --dry-run --repo my-repo-name
```
Only that repo is processed; all others are silently skipped. Use this to test the script on one repo before doing the full run.

### After the rollout

Enable branch protection rules in each repo under **Settings → Branches** and require `check-branch-name` and `check-pr-title` status checks to pass before merging.

---

## Org Repo Reference

Full list of active (non-archived) repos in `hard-software-au` as of 2026-03-26.
Use these names with `--repo` to target a specific repo.

> Always excluded by the script: `.github`, `infolite-core`

| Repo name | `--repo` value |
|---|---|
| hard-software-au/alerts-caller | `alerts-caller` |
| hard-software-au/alerts-dashboard | `alerts-dashboard` |
| hard-software-au/assets | `assets` |
| hard-software-au/auth0-audits | `auth0-audits` |
| hard-software-au/auto-bidder-engine | `auto-bidder-engine` |
| hard-software-au/availability-api | `availability-api` |
| hard-software-au/deployment-dashboard | `deployment-dashboard` |
| hard-software-au/direct-plant-control-api | `direct-plant-control-api` |
| hard-software-au/fast-api-test | `fast-api-test` |
| hard-software-au/fcas | `fcas` |
| hard-software-au/gendirector-api | `gendirector-api` |
| hard-software-au/generation-management-system | `generation-management-system` |
| hard-software-au/generator-api | `generator-api` |
| hard-software-au/generator-api-client-spec | `generator-api-client-spec` |
| hard-software-au/gpg_auto-bidder-engine | `gpg_auto-bidder-engine` |
| hard-software-au/gpg_generator-api | `gpg_generator-api` |
| hard-software-au/hpr | `hpr` |
| hard-software-au/hpr-app | `hpr-app` |
| hard-software-au/hs_bidding | `hs_bidding` |
| hard-software-au/infolite-legacy | `infolite-legacy` |
| hard-software-au/infolite-web-app | `infolite-web-app` |
| hard-software-au/infrastructure | `infrastructure` |
| hard-software-au/kennedy-esm | `kennedy-esm` |
| hard-software-au/landing-page | `landing-page` |
| hard-software-au/optigen-bidding | `optigen-bidding` |
| hard-software-au/optigen-common | `optigen-common` |
| hard-software-au/optigen-configuration | `optigen-configuration` |
| hard-software-au/optigen-manager | `optigen-manager` |
| hard-software-au/optigen-market-data-reader | `optigen-market-data-reader` |
| hard-software-au/optigen-mongo-loader | `optigen-mongo-loader` |
| hard-software-au/optigen-monitor | `optigen-monitor` |
| hard-software-au/optigen-MQTT-dashboard | `optigen-MQTT-dashboard` |
| hard-software-au/optigen-optimiser | `optigen-optimiser` |
| hard-software-au/optigen-rut-reader | `optigen-rut-reader` |
| hard-software-au/optigen-rut-writer | `optigen-rut-writer` |
| hard-software-au/optigen-sql-loader | `optigen-sql-loader` |
| hard-software-au/optigen-web-app | `optigen-web-app` |
| hard-software-au/outage-alert-manger | `outage-alert-manger` |
| hard-software-au/participant-pwd-reset | `participant-pwd-reset` |
| hard-software-au/pydatafeed | `pydatafeed` |
| hard-software-au/pydnp3 | `pydnp3` |
| hard-software-au/pyqueueloader | `pyqueueloader` |
| hard-software-au/pyscada | `pyscada` |
| hard-software-au/Report-Checker | `Report-Checker` |
| hard-software-au/short-term-forecasting | `short-term-forecasting` |
| hard-software-au/signal-list-template | `signal-list-template` |
