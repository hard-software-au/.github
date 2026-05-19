# CI Pre-commit Runner Container — Implementation Checklist

**Goal:** Replace per-run package installation in `reusable-pre-commit.yml` with a pre-built Docker image
hosted on GHCR. Expected job time: ~5 min → ~45–90 sec cold, ~20–30 sec warm (cached hook envs).

---

## 1. Audit & decide what goes in the image

- [x] **System packages**: `gitleaks`, `curl`, `git`
- [x] **Python packages** (all profiles): `pre-commit`, `detect-secrets`, `ruff`, `mypy`, `pip-audit`, `ansible`, `ansible-lint`, `yamllint`, `checkov`
- [x] **Ruby gems**: `rubocop`, `rubocop-rails`
- [x] **Node.js**: LTS (needed for `prettier` and `eslint` hook environments at runtime)
- [x] **Decision**: one image covering all profiles (simpler rebuild cadence, avoids matrix complexity)

---

## 2. Create the Dockerfile

- [ ] Create `docker/pre-commit-runner/Dockerfile`
- [ ] Base image: `python:3.11-slim` (avoids apt overhead vs ubuntu-latest, smaller image)
- [ ] Layer order: system pkgs → Node.js → Ruby → pip install → gem install
- [ ] Pin all package versions to match profile `.yaml` files:
  - `ansible-lint==6.28.3`, `ruff==0.5.5`, `mypy==1.11.1`, `checkov` (latest stable)
  - `rubocop` + `rubocop-rails` (match `ruby.yaml` rev)
- [ ] Add `LABEL org.opencontainers.image.*` metadata (source, version, description)

---

## 3. Create the container build & publish workflow

- [ ] Create `workflows/build-pre-commit-runner.yml`
- [ ] Triggers:
  - `push` to `main` when `docker/**` or `pre-commit-profiles/**` changes
  - `workflow_dispatch` (manual rebuild)
- [ ] Use `docker/build-push-action` to build and push to `ghcr.io/hard-software-au/pre-commit-runner`
- [ ] Tag strategy: `latest` + git SHA (allows pinning to a SHA if `latest` breaks something)
- [ ] Job permissions: `contents: read`, `packages: write`

---

## 4. Update `reusable-pre-commit.yml` to use the container

- [ ] Add `container: ghcr.io/hard-software-au/pre-commit-runner:latest` to the job
- [ ] Remove steps no longer needed (all handled by image):
  - `Install gitleaks (system prerequisite)`
  - `Set up Python`
  - `Set up Node.js`
  - `Install pre-commit and profile dependencies`
- [ ] Add `cache` step for `~/.cache/pre-commit` (hook environments — largest remaining time sink)
  - Cache key: hash of the generated `.pre-commit-config.yaml`
  - Restore key: profile string prefix (partial cache hit on minor version bumps)
- [ ] Job permissions: add `packages: read`

---

## 5. GHCR auth

- [ ] Confirm `GITHUB_TOKEN` for org repos has read access to `ghcr.io/hard-software-au` packages
- [ ] For private repos: verify package visibility is set to `internal` (not `private`) in GHCR settings so all org repos can pull without extra secrets

---

## 6. Test & validate

- [ ] Build image locally: `docker build -t pre-commit-runner docker/pre-commit-runner/`
- [ ] Smoke test locally: `docker run --rm -v $(pwd):/repo -w /repo pre-commit-runner pre-commit run --all-files`
- [ ] Push to `main` and verify `build-pre-commit-runner.yml` triggers and image appears in GHCR
- [ ] Trigger a PR in `infolite-core` and measure job time before/after
- [ ] Verify cache hit on a second run (check "Cache restored" in Actions log)

---

## 7. Integrate container build into `rollout-devops-assets.sh`

- [ ] Add `docker/pre-commit-runner/Dockerfile` to the list of assets deployed to target repos
  (so repos get a local copy for reference, or decide to exclude and keep it `.github`-only)
- [ ] Ensure `workflows/build-pre-commit-runner.yml` is included in the workflows deployed by the rollout script
- [ ] Verify the rollout script's `git add` and `git diff --quiet` checks cover the new `docker/` directory
- [ ] Test with `--dry-run` against one repo before a full org rollout:
  ```sh
  ./rollout-devops-assets.sh --dry-run --repo infolite-core --profiles baseline,python,ruby
  ```

---

## 8. Rollout to target repos

- [ ] No changes to target repo workflows — they call `reusable-pre-commit.yml` which is updated centrally ✓
- [ ] Re-run `rollout-devops-assets.sh` for any repos that need the updated `reusable-pre-commit.yml`
  pushed to their `.github/workflows/` directory

---

## Reference

| Profile   | Key pip packages                              | Key gem packages        | System |
|-----------|-----------------------------------------------|-------------------------|--------|
| baseline  | `pre-commit`, `detect-secrets`                | —                       | `gitleaks` |
| python    | `ruff`, `mypy`, `pip-audit`                   | —                       | — |
| node      | —                                             | —                       | `node` (LTS) |
| ruby      | —                                             | `rubocop`, `rubocop-rails` | — |
| ansible   | `ansible`, `ansible-lint`, `yamllint`, `checkov` | —                    | — |
