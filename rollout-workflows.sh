#!/bin/zsh
# rollout-workflows.sh
#
# Copies branch-name-check.yml and pr-title-check.yml to every repo in a GitHub
# org and opens a PR in each one.  Repos that already have both files are skipped.
#
# Requirements:
#   - gh CLI installed and authenticated  (brew install gh)
#   - git configured with credentials that can push to the org
#
# Usage:
#   ./rollout-workflows.sh            # live run — pushes branches and opens PRs
#   ./rollout-workflows.sh --dry-run  # preview only — no git push, no PRs
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Dry-run flag ──────────────────────────────────────────────────────────────
DRY_RUN=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

# ── Configuration ─────────────────────────────────────────────────────────────
ORG="hard-software-au"          # ← replace with your GitHub organisation slug

PR_BRANCH="chore/add-naming-convention-workflows"
PR_TITLE="chore: add branch name and PR title check workflows"
PR_BODY="Adds \`branch-name-check.yml\` and \`pr-title-check.yml\` to enforce the team's naming conventions.\n\nSee the org \`.github\` repo README for details."

# Source workflow files (sit alongside this script in the .github repo)
SCRIPT_DIR="${${(%):-%x}:A:h}"
WORKFLOW_SRC_DIR="$SCRIPT_DIR"
# ─────────────────────────────────────────────────────────────────────────────

# ── Pre-flight checks ──────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI not found.  Install with: brew install gh"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "ERROR: not authenticated with gh.  Run: gh auth login"
  exit 1
fi

for f in branch-name-check.yml pr-title-check.yml; do
  [[ -f "$WORKFLOW_SRC_DIR/$f" ]] || {
    echo "ERROR: source file not found: $WORKFLOW_SRC_DIR/$f"
    exit 1
  }
done

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# ── Fetch repo list ────────────────────────────────────────────────────────────
echo "Fetching repo list for org: $ORG …"
REPOS=$(gh repo list "$ORG" --no-archived --limit 200 --json nameWithOwner --jq '.[].nameWithOwner')

if [[ -z "$REPOS" ]]; then
  echo "No repos found (check your ORG value and gh authentication)."
  exit 1
fi

SKIPPED=()
ALREADY_DONE=()
CREATED=()
WOULD_CREATE=()
FAILED=()

# ── Process each repo ──────────────────────────────────────────────────────────
for REPO in ${(f)REPOS}; do
  REPO_NAME="${REPO##*/}"

  # Skip the reference repo and the org-level .github repo
  if [[ "$REPO_NAME" == "infolite-core" || "$REPO_NAME" == ".github" ]]; then
    SKIPPED+=("$REPO_NAME")
    echo "⏭  $REPO_NAME — skipped (excluded)"
    continue
  fi

  echo "\n── $REPO ──────────────────────────────────────────────────────────"

  CLONE_DIR="$WORK_DIR/$REPO_NAME"

  if ! gh repo clone "$REPO" "$CLONE_DIR" -- --depth=1 --quiet 2>/dev/null; then
    echo "  ✗ clone failed — skipping"
    FAILED+=("$REPO_NAME (clone failed)")
    continue
  fi

  DEST_DIR="$CLONE_DIR/.github/workflows"

  # Skip if both files already exist
  if [[ -f "$DEST_DIR/branch-name-check.yml" && -f "$DEST_DIR/pr-title-check.yml" ]]; then
    echo "  ✓ workflows already present — skipping"
    ALREADY_DONE+=("$REPO_NAME")
    continue
  fi

  DEFAULT_BRANCH=$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name')

  if $DRY_RUN; then
    echo "  [dry-run] would add workflows and open PR → $PR_BRANCH → $DEFAULT_BRANCH"
    WOULD_CREATE+=("$REPO_NAME")
    continue
  fi

  mkdir -p "$DEST_DIR"
  cp "$WORKFLOW_SRC_DIR/branch-name-check.yml" "$DEST_DIR/"
  cp "$WORKFLOW_SRC_DIR/pr-title-check.yml"    "$DEST_DIR/"

  pushd "$CLONE_DIR" >/dev/null

  git checkout -b "$PR_BRANCH"
  git add .github/workflows/branch-name-check.yml .github/workflows/pr-title-check.yml
  git commit -m "$PR_TITLE"

  if ! git push origin "$PR_BRANCH" --quiet 2>/dev/null; then
    echo "  ✗ push failed — skipping PR creation"
    popd >/dev/null
    FAILED+=("$REPO_NAME (push failed)")
    continue
  fi

  gh pr create \
    --title  "$PR_TITLE" \
    --body   "$(printf '%b' "$PR_BODY")" \
    --base   "$DEFAULT_BRANCH" \
    --head   "$PR_BRANCH"

  popd >/dev/null

  echo "  ✓ PR created"
  CREATED+=("$REPO_NAME")
done

# ── Summary ────────────────────────────────────────────────────────────────────
echo "\n══════════════════════════════════════════════════════════"
$DRY_RUN && echo "  DRY RUN — no changes were made." || echo "  Done."
if $DRY_RUN; then
  echo "  Would create PRs : ${#WOULD_CREATE[@]}"
else
  echo "  PRs created      : ${#CREATED[@]}"
fi
echo "  Already done : ${#ALREADY_DONE[@]}"
echo "  Skipped      : ${#SKIPPED[@]}"
echo "  Failed       : ${#FAILED[@]}"

if $DRY_RUN && (( ${#WOULD_CREATE[@]} > 0 )); then
  echo "\n  Would open PRs in:"
  for r in $WOULD_CREATE; do echo "    • $r"; done
fi

if ! $DRY_RUN && (( ${#CREATED[@]} > 0 )); then
  echo "\n  New PRs:"
  for r in $CREATED; do echo "    • $r"; done
fi

if (( ${#FAILED[@]} > 0 )); then
  echo "\n  Failures:"
  for r in $FAILED; do echo "    • $r"; done
fi
echo "══════════════════════════════════════════════════════════"
