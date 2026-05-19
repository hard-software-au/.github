# Bootstrap Hooks and Helper Scripts

This directory contains the bootstrap tooling and helper scripts for pre-commit hook installation across all org repositories.

## Contents

### `bootstrap-hooks.sh`

Automated setup script that:
1. Fetches profiles from `.github/pre-commit-profiles/`
2. Merges profiles into a single `.pre-commit-config.yaml`
3. Extracts tool dependencies from profiles
4. Creates/updates `.venv` with required packages
5. Installs pre-commit hooks (`pre-commit`, `pre-push`, and `commit-msg` stages)
6. Creates initial `.secrets.baseline` file

**Usage:**

```bash
# For Python repos
./scripts/bootstrap-hooks.sh baseline python

# For Node.js repos
./scripts/bootstrap-hooks.sh baseline node

# For Ansible/infrastructure repos
./scripts/bootstrap-hooks.sh baseline ansible

# For Ruby repos
./scripts/bootstrap-hooks.sh baseline ruby

# Multi-language repos (e.g., Rails with some shell scripts)
./scripts/bootstrap-hooks.sh baseline python ruby
```

**What it does:**

1. Validates profiles exist and are accessible
2. Merges YAML repos from all profiles into single `.pre-commit-config.yaml`
3. Adds managed header (file is auto-generated; do not edit directly)
4. Extracts venv dependencies from `# Install:` comments in profile headers
5. Creates `python3 -m venv .venv` if Python packages required
6. `pip install <packages>` into venv
7. `pre-commit install --hook-type pre-commit --hook-type pre-push --hook-type commit-msg`
8. Generates initial `.secrets.baseline` via `detect-secrets scan`

**Output:**

- `.pre-commit-config.yaml` — repo-level config (marked as auto-generated)
- `.venv/` — Python virtual environment (if Python packages required)
- `.secrets.baseline` — secrets baseline for detect-secrets hook

**Regeneration:**

If profiles are updated in `.github`, regenerate locally:

```bash
./scripts/bootstrap-hooks.sh baseline python  # Re-run bootstrap
pre-commit autoupdate  # Optional: update hook revisions to latest
```

### `commit-msg-check.sh`

Enforces commit message conventions across all repos. Validates:
- **First line:** < 50 chars, capitalized, imperative mood
- **Blank line:** Required after first line if body present
- **Body lines:** < 72 chars (recommended)
- **Format:** No period at end of first line

**Usage:** Called automatically by pre-commit via `commit-msg` hook (declared in baseline.yaml)

**Validation rules:**

1. First line < 50 characters
2. First line must not be empty
3. First character must be capitalized
4. (Warning) First line should not end with period
5. If body present, second line must be blank
6. (Warning) Body lines > 72 chars

**Examples — valid commits:**

```
Fix database connection issue
Add user authentication endpoint
Refactor deployment script for clarity
```

**Examples — invalid commits:**

```
fixed a bug                           # Not capitalized
This is a very long first line that exceeds the 50 character limit.
                                      # Empty first line
Fix a bug
additional details here without blank line  # Missing blank line
```

### `pip-audit-warn.sh`

Runs `pip-audit` in advisory mode and always exits `0` so dependency advisories are visible without blocking pushes.

Behavior:
- Uses `.venv/bin/pip-audit` when available
- Falls back to system `pip-audit` if installed
- Warns and skips when `pip-audit` is unavailable

## Integration with rollout-workflows.sh

The `.github/rollout-workflows.sh` script automatically deploys **all** `.sh` files from this directory to target repos:
- `.github/scripts/*.sh` → `scripts/*.sh` in target repo
- `.github/pre-commit-profiles/*.yaml` → `pre-commit-profiles/` in target repo
- `.github/workflows/*.yml` → `.github/workflows/` in target repo
- Profile-linked config files (`git-hook-config/.prettierrc`, plus `git-hook-config/.ansible-lint`/`git-hook-config/.yamllint` when `ansible` is selected)

Each target repo then runs bootstrap (`./scripts/bootstrap-hooks.sh <profiles>`) with the appropriate profile list for that repo's tech stack.
