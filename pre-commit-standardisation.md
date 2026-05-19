# Pre-commit Standardisation Checklist

Tracks the rollout of org-wide pre-commit hooks across all repos.
The prototype lives in `infrastructure/.pre-commit-config.yaml`. Everything else migrates to use the shared profiles defined here.

---

## Recommended Execution Order

Follow this sequence to minimise churn and make rollback easy:

1. Foundation in `.github` (this repo)
  - Complete §0 (prototype extraction) and §1 (profile definitions)
  - Complete §2 (bootstrap tooling) so profile assembly is automated and repeatable
  - Complete §3 (reusable CI workflow) so enforcement is available before broad rollout
2. Validate against `infrastructure` first (Priority 1)
  - Use `baseline` + `ansible` profiles as the first production proving ground
  - Confirm parity with existing `playbook-dev_setup.yml` behaviour and hook outcomes
3. Roll out targeted pilot in `infolite-core` for `ansible/dc-24`
  - Generate repo config from shared profiles, scoped to `ansible/dc-24/` only for initial adoption
  - Install both local hooks: pre-commit and pre-push
  - Run full hook suite and fix issues before enabling branch protection requirements
4. Expand to remaining repos by §4 migration order
  - Progress from priorities 2 → 5 after pilot stability
5. Operationalise maintenance
  - Complete §5 and §6 (versioning, exceptions, upgrade process)

**Gate rule:** do not onboard additional repos until the previous step is green in both local runs and CI.

**Rollout enforcement rule:** deployment of shared workflows and git-hook assets to downstream repos must occur via `.github/rollout-workflows.sh` only (no manual file copy PRs).

---

## 0. Port the prototype from `infrastructure/`

The `infrastructure/` repo has a working `.pre-commit-config.yaml` prototype. Use it as the canonical starting point before defining profiles in §1.

- [x] Review `infrastructure/.pre-commit-config.yaml` — confirm all hooks are current and the prototype is stable enough to extract from
- [x] Copy `infrastructure/.pre-commit-config.yaml` into `.github/reference/` as a locked reference copy (`.pre-commit-config.infrastructure-prototype.yaml`, copied 2026-05-19). Useful for auditing profile extraction; not deployed.
- [x] Note any hooks that are currently infrastructure-specific (e.g. scoped to `ubuntu24/`) and must be generalised before landing in a shared profile:
  - `ansible-lint` entry path (`ubuntu24/.dev-venv/bin/ansible-lint ubuntu24/`) — must become repo-relative in the ansible profile
  - `yamllint`, `ansible-syntax-check`, `checkov`, `pip-audit` — same generalisation needed
  - `detect-secrets` baseline path (`ubuntu24/.secrets.baseline`) — each repo will have its own baseline
  - `prettier` `files:` scope (`^ubuntu24/`) — must be removed from the shared profile (caller scopes it)
- [x] Document `gitleaks` as a self-service prerequisite (it is `language: system` — not in the venv):
  - Gitleaks installation instructions added to `.github/README.md` (manual fallback commands: apt, brew, chocolatey)
  - Gitleaks installation added to `infrastructure/ubuntu24/playbook-dev_setup.yml` and equivalent bootstrap scripts (auto-installed when developers run playbook)
  - Developers must install individually (either via playbook or manual commands) before running hooks locally; not org-wide enforced
- [x] Confirm pinned versions from the prototype are still current before locking them in profiles:
  - ✅ `prettier`: **Latest version, direct `prettier` hook** (not archived mirrors-prettier)
  - ✅ `pre-commit-hooks`: **v6.0.0** (Aug 2025, latest). Stage 1 profiles will pin to v6.0.0.

Stage 0 progress note (2026-05-19): **COMPLETE**. Prototype extracted, version pins locked (prettier latest + pre-commit-hooks v6.0.0), infrastructure-specific paths identified, gitleaks prerequisite documented (self-service via playbook or manual). Ready for Stage 1 profile definitions.

---

## 1. Define profiles

- [x] **`pre-commit-profiles/baseline.yaml`** — split from `infrastructure/.pre-commit-config.yaml`
  - `no-commit-to-branch` (main, master)
  - `gitleaks protect --staged`
  - `detect-secrets-hook` with repo-level `.secrets.baseline`
  - `commit-msg-check.sh`
  - Prettier (caller repos scope via `files:`)
  - Pins: pre-commit-hooks v6.0.0, prettier latest
- [x] **`pre-commit-profiles/python.yaml`**
  - `ruff` (lint + format, v0.5.5)
  - `mypy` (type checking, v1.11.1)
  - `pip-audit` (advisory, non-blocking)
  - Applies to: `availability-api`, `generator-api`, `direct-plant-control-api`, `auto-bidder-engine`, `optigen-*`, `pyscada`, `pyqueueloader`, `xen-orchestra-audits`, `auth0-audits`, `infolite-core` (lib only)
- [x] **`pre-commit-profiles/node.yaml`**
  - `eslint` (v9.9.0)
  - Prettier via baseline
  - Applies to: `infolite-web-app`, `optigen-web-app`
- [x] **`pre-commit-profiles/ruby.yaml`**
  - `rubocop --autocorrect-all` (v1.3.1)
  - Applies to: `infolite-core` (Rails)
- [x] **`pre-commit-profiles/ansible.yaml`**
  - `ansible-lint` (v6.28.3)
  - `yamllint` (v1.35.1)
  - `ansible-playbook --syntax-check`
  - `checkov`
  - Applies to: `infrastructure`

Stage 1.1 complete (2026-05-19): All 5 profiles created with repo-agnostic scoping, tool versions pinned, hardcoded paths removed.

---

## 2. Create bootstrap tooling

Current behavior snapshot (as of 2026-05-19):
- `bootstrap-hooks.sh` installs hook types: `pre-commit`, `pre-push`, `commit-msg`
- Prefers venv-local tools when available (`.venv/bin/pre-commit`, `.venv/bin/detect-secrets`)
- Generates `.secrets.baseline` (warn-only fallback when detect-secrets missing)

- [x] **`scripts/bootstrap-hooks.sh`** — takes profile list, fetches from `.github/pre-commit-profiles/`, merges into `.pre-commit-config.yaml`, installs venv, runs `pre-commit install` and `pre-commit install --hook-type pre-push`
  - Updated behavior: installs `pre-commit`, `pre-push`, and `commit-msg` hooks.
  - Injects managed header into generated config ("do not edit directly")
  - Extracts venv dependencies from `# Install:` comments in profiles
  - Creates `.venv` with pip/gem packages for repo
  - Creates `.secrets.baseline` via `detect-secrets scan`
  - Documented in `scripts/README.md`
- [x] Bootstrap installs all required hook types by default: `pre-commit`, `pre-push`, `commit-msg`
- [x] Each profile declares its own venv dependencies (via `# Install:` header comments; no kitchen-sink installs)
- [x] Rollout integration: `rollout-workflows.sh` already deploys:
  - `scripts/*.sh` → target repo `scripts/`
  - Selected `pre-commit-profiles/*.yaml` (from `--profiles`) → target repo `pre-commit-profiles/`
  - `.github/workflows/*.yml` → target repo `.github/workflows/`
  - Profile-linked config files: `git-hook-config/.prettierrc` always, plus `git-hook-config/.ansible-lint`/`git-hook-config/.yamllint` when `ansible` profile is selected
  - Detects if files already present (skips if no net-new content)
- [ ] Document one-liner dev setup commands in each repo's `README.md` template; Bootstrap integration complete (2026-05-19).

Stage 1.2 progress note (2026-05-19): **COMPLETE**. Bootstrap tooling (scripts/bootstrap-hooks.sh) created, venv dependency isolation via profiles, rollout integration verified. One-liner documentation deferred to Stage 3 (per-repo README updates).

---

## 3. Create reusable CI workflow

Current behavior snapshot (as of 2026-05-19):
- CI installs both `pre-commit` and `detect-secrets`
- Pre-commit pass/fail is based on command exit code (`pipefail`), not log grepping
- Workflow remains profile-driven via `workflow_call` input `profiles`

- [x] **`.github/workflows/reusable-pre-commit.yml`** — callable via `workflow_call`
  - Accepts inputs: `profiles` (comma-separated list), `python-version`, `node-version`
  - Checks out calling repo
  - Fetches profiles from `.github/pre-commit-profiles/`
  - Generates `.pre-commit-config.yaml` by merging selected profiles
  - Runs `pre-commit run --all-files` against merged config
  - Fails PR if any check fails; uploads log on failure
  - Installs gitleaks system-wide (prerequisite)
- [x] **`.github/workflows/pre-commit-template.yml`** — template for individual repos to copy and customize
  - Shows how to call reusable workflow with profile examples
  - Triggers on PR and push to main/develop
  - Documented in `.github/workflows/README.md`
- [x] **Visibility check**: Reusable workflows callable cross-org via `uses: <owner>/.github/workflows/reusable-pre-commit.yml` (requires repo or personal access token)

Stage 2 complete (2026-05-19): Reusable CI workflow + template created. Profile merging, hook execution, and result reporting automated.

---

## 4. Wire up each repo

For each repo below, complete all steps:

- [ ] Add `.pre-commit-config.yaml` declaring only its required profiles (generated by `bootstrap-hooks.sh`), with a header comment stating the file is managed by the org `.github` repo — do not edit directly
- [ ] Add `.github/workflows/pre-commit.yml` calling the reusable workflow with the correct profile list
- [ ] Add `playbook-dev_setup.yml` or equivalent `bootstrap.sh` to the repo root, and document the setup command in `README.md`
- [ ] Create initial `.secrets.baseline` via `detect-secrets scan` and commit it
- [ ] Add branch protection rule requiring the pre-commit CI check to pass before merge
- [ ] Use `.github/rollout-workflows.sh` to open rollout PRs for this wiring (do not hand-craft copy PRs)

### Migration order

| Priority | Repo | Profiles |
|---|---|---|
| 1 | `infrastructure` | baseline, ansible |
| 2 | `availability-api` | baseline, python |
| 2 | `generator-api` | baseline, python |
| 2 | `direct-plant-control-api` | baseline, python |
| 3 | `infolite-core` | baseline, python, ruby, ansible |
| 4 | `infolite-web-app` | baseline, node |
| 5 | `auto-bidder-engine` | baseline, python |
| 5 | `optigen-monitor` | baseline, python |
| 5 | `optigen-rut-reader` | baseline, python |
| 5 | `optigen-MQTT-dashboard` | baseline, python |
| 5 | `optigen-web-app` | baseline, node |
| 5 | `pyscada` | baseline, python |
| 5 | `pyqueueloader` | baseline, python |
| 5 | `xen-orchestra-audits` | baseline, python |
| 5 | `auth0-audits` | baseline, python |

### Initial pilot scope note

- [ ] For `infolite-core`, onboard `ansible/dc-24/` first as a constrained pilot before enabling hooks across the full repo

---

## 5. Maintenance

- [ ] Pin all profile tool versions explicitly — no `latest` anywhere
- [ ] Set up Dependabot or Renovate on `.github` repo to auto-PR tool version bumps in profiles
- [ ] Establish upgrade process: version bump PR in `.github` → teams update their repo's declared profile version — no forced upgrades without notice
- [ ] Add `pre-commit-profiles/CHANGELOG.md` to track breaking changes per profile

---

## 6. Exception handling

- [ ] Document the process for repos that cannot comply immediately (legacy stack, EOL runtime)
- [ ] At minimum, all repos must pass the **baseline** profile — no exceptions to this rule
