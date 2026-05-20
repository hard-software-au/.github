# Pre-commit Reusable Workflow

This directory contains shared GitHub Actions workflows for org-wide standardization.

## `reusable-pre-commit.yml`

A reusable GitHub Actions workflow that orchestrates pre-commit hook checks for any repository. This workflow:

1. **Checks out the calling repo** to validate
2. **Fetches org profiles** from the `.github` repo
3. **Generates `.pre-commit-config.yaml`** by merging selected profiles
4. **Runs pre-commit checks** against all files with `pre-commit run --all-files`
5. **Reports results** and fails the workflow if any check fails

### Inputs

| Input            | Required | Default | Description                                                                       |
| ---------------- | -------- | ------- | --------------------------------------------------------------------------------- |
| `profiles`       | Yes      | —       | Comma-separated list of profiles: `baseline`, `python`, `node`, `ruby`, `ansible` |
| `python-version` | No       | `3.11`  | Python version for venv                                                           |
| `node-version`   | No       | `20`    | Node.js version (if `node` profile used)                                          |

### Usage

In your repo's `.github/workflows/pre-commit.yml`:

```yaml
name: Pre-commit Hooks

on:
  pull_request:
  push:
    branches: [main, master]

jobs:
  pre-commit:
    name: Pre-commit Checks
    uses: ./.github/workflows/reusable-pre-commit.yml
    with:
      profiles: baseline,python
      python-version: "3.11"
```

### Profile Combinations

Choose profiles based on your repo's tech stack:

| Tech Stack                         | Profiles                            |
| ---------------------------------- | ----------------------------------- |
| **Python (CLI/backend)**           | `baseline,python`                   |
| **Python (with pip audits)**       | `baseline,python`                   |
| **Node.js (frontend/backend)**     | `baseline,node`                     |
| **Ruby on Rails**                  | `baseline,python,ruby`              |
| **Ansible / Infrastructure**       | `baseline,ansible`                  |
| **Multi-language (Rails + shell)** | `baseline,python,ruby`              |
| **All languages**                  | `baseline,python,node,ruby,ansible` |

### What Happens

1. **Environment Setup:**
   - Python runtime setup
   - `pre-commit` and `detect-secrets` installed in CI
   - gitleaks installed system-wide
   - Node.js (if required)

2. **Config Generation:**
   - Fetches each profile YAML from `.github/pre-commit-profiles/`
   - Merges them into a single `.pre-commit-config.yaml`
   - Adds header marking it as auto-generated

3. **Hook Execution:**
   - `pre-commit run --all-files` with selected profiles
   - Runs all hooks in the combined config
   - Reports pass/fail for each hook

4. **Artifact Upload:**
   - On failure, uploads `pre-commit.log` for debugging

5. **Validation behavior:**
   - Invalid profile names fail fast with a clear "profile not found" error
   - Workflow pass/fail is based on `pre-commit` command exit code

### Branch Protection

Set up branch protection to **require** this workflow to pass:

1. Go to repo Settings → Branches → Default branch rules
2. Enable "Require status checks to pass before merging"
3. Search for "Pre-commit Checks" and add it to required checks
4. Save

### Troubleshooting

**Workflow fails with "profile not found":**

- Verify profile name is spelled correctly (e.g., `node` not `nodejs`)
- Available profiles: `baseline`, `python`, `node`, `ruby`, `ansible`

**Workflow fails on `gitleaks` installation:**

- Ensure gitleaks is installed on your machine: `brew install gitleaks` (macOS) or `apt install gitleaks` (Linux)
- Workflow auto-installs on CI runner

**Template workflow fails in target repo:**

- Ensure `.github/workflows/reusable-pre-commit.yml` exists in the same repo
- Update `profiles:` in `pre-commit-template.yml` to match the repo stack before merging

**Workflow fails with profile mismatch:**

- Check the `profiles:` value in workflow call
- Available profiles: `baseline`, `python`, `node`, `ruby`, `ansible`

### Local Testing

To test locally before pushing:

```bash
# Generate config with selected profiles
./scripts/bootstrap-hooks.sh baseline python

# Run all checks
pre-commit run --all-files

# Fix auto-correctable issues
pre-commit run --all-files --show-diff-on-failure
```

## `pre-commit-template.yml`

A template workflow that repos can copy/customize. Includes:

- Trigger on pull requests and pushes to main/master
- Calls `reusable-pre-commit.yml` with profile list
- Shows examples of profile combinations

### For Repo Teams

1. Copy this template into your repo as `.github/workflows/pre-commit.yml`
2. Update the `profiles:` line to match your repo's tech stack
3. Commit and push
4. Workflow runs automatically on future PRs

### Example Customizations

**Python project:**

```yaml
profiles: baseline,python
```

**Rails project (Python + Ruby):**

```yaml
profiles: baseline,python,ruby
```

**Node.js + some Python:**

```yaml
profiles: baseline,node,python
```

---

## FAQ

**Q: Can I run different hooks in CI vs. locally?**
A: Yes. Locally, run `./scripts/bootstrap-hooks.sh baseline python`. In CI, specify different profiles in the workflow call.

**Q: What if a hook is slow or flaky?**
A: Temporarily disable it in your `.pre-commit-config.yaml` by setting `stages: []` for that hook. Report to the org admin for potential profile adjustment.

**Q: How do I know if a profile was updated?**
A: Watch the `.github` repo or check release notes. Workflows will automatically use the latest profiles on the next PR.
