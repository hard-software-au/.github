# Workflow Directory Notes

This directory contains executable GitHub Actions workflow files for this repository.

## Path Map (from repo root)

- Source templates: `./workflows/`
- Executable workflows: `./.github/workflows/`

In this repository, you are inside the repo named `.github`, so `./.github/workflows/` can look like "double .github" in absolute paths. It is still the normal GitHub Actions location inside the repo.

## Ownership Model

- Source workflow definitions are maintained in `./workflows/`.
- Files in `./.github/workflows/` are synced copies used for GitHub Actions execution.

## How To Update Workflows

1. Edit the source files in `./workflows/`.
2. Sync the updated workflow `.yml` files into `./.github/workflows/`.
3. Commit and merge in the `.github` repo.
4. Roll out to target repositories with:

```bash
./rollout-devops-assets.sh --repo <repo> --profiles <profiles>
```

The `.github` repository itself is updated directly via normal PRs.
