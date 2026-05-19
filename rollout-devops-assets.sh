#!/bin/zsh
# rollout-devops-assets.sh
#
# Copies workflow templates from this repo into every repo in a GitHub
# org and opens a PR in each one. Repos that already have all workflow files are skipped.
#
# Requirements:
#   - gh CLI installed and authenticated  (brew install gh)
#   - git configured with credentials that can push to the org
#
# Usage:
#   ./rollout-devops-assets.sh                        # live run — all repos
#   ./rollout-devops-assets.sh --dry-run              # preview only — no git push, no PRs
#   ./rollout-devops-assets.sh --repo my-repo-name    # target a single repo
#   ./rollout-devops-assets.sh --dry-run --repo my-repo-name
#   ./rollout-devops-assets.sh --profiles baseline,python,ansible  # specify profiles
#   ./rollout-devops-assets.sh --profiles baseline,ansible --repo infrastructure  # combine flags
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail
setopt null_glob

# ── Flags ────────────────────────────────────────────────────────────────────
DRY_RUN=false
ONLY_REPO=""
PROFILES="baseline"  # default: baseline only

while (( $# > 0 )); do
  case "$1" in
    --dry-run)     DRY_RUN=true ;;
    --repo)        shift; ONLY_REPO="$1" ;;
    --profiles)    shift; PROFILES="$1" ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
  shift
done

# ── Configuration ─────────────────────────────────────────────────────────────
ORG="hard-software-au"          # ← replace with your GitHub organisation slug

PR_BRANCH="bot/chore/rollout-org-automation-standards"
PR_TITLE="chore: rollout org workflow and hook standards"

# Source workflow files from the dedicated workflows/ directory first, then fall back to the repo root for older layouts.
SCRIPT_DIR="${${(%):-%x}:A:h}"
WORKFLOW_SRC_DIR="$SCRIPT_DIR/workflows"
if [[ ! -d "$WORKFLOW_SRC_DIR" ]]; then
  WORKFLOW_SRC_DIR="$SCRIPT_DIR/.github/workflows"
fi
if [[ ! -d "$WORKFLOW_SRC_DIR" ]]; then
  WORKFLOW_SRC_DIR="$SCRIPT_DIR"
fi
HOOK_PROFILE_SRC_DIR="$SCRIPT_DIR/pre-commit-profiles"
SCRIPTS_SRC_DIR="$SCRIPT_DIR/scripts"
TEMPLATES_SRC_DIR="$SCRIPT_DIR/templates"

# Determine selected profiles and validate them.
if [[ ! -d "$HOOK_PROFILE_SRC_DIR" ]]; then
  echo "ERROR: pre-commit profiles directory not found at: $HOOK_PROFILE_SRC_DIR"
  exit 1
fi

PROFILE_INPUT=(${(s:,:)PROFILES})
SELECTED_PROFILES=()
for profile in $PROFILE_INPUT; do
  profile="${profile// /}"
  [[ -z "$profile" ]] && continue
  if [[ ! -f "$HOOK_PROFILE_SRC_DIR/$profile.yaml" ]]; then
    echo "ERROR: unknown profile: $profile"
    echo "Available profiles:"
    ls -1 "$HOOK_PROFILE_SRC_DIR"/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/\.yaml$//' || true
    exit 1
  fi
  SELECTED_PROFILES+=("$profile")
done

if (( ${#SELECTED_PROFILES[@]} == 0 )); then
  echo "ERROR: no valid profiles selected"
  exit 1
fi

PROFILE_FILES=()
for profile in $SELECTED_PROFILES; do
  PROFILE_FILES+=("$HOOK_PROFILE_SRC_DIR/$profile.yaml")
done

PROFILES_CANONICAL="$(IFS=,; echo "${SELECTED_PROFILES[*]}")"

# Determine config files to deploy based on selected profiles (prettier always, ansible-specific configs conditionally)
CONFIG_FILES_TO_DEPLOY=("git-hook-config/.prettierrc")
if [[ " ${SELECTED_PROFILES[*]} " == *" ansible "* ]]; then
  CONFIG_FILES_TO_DEPLOY+=("git-hook-config/.ansible-lint" "git-hook-config/.yamllint")
fi

SETUP_METHOD=""
if [[ -x "$(command -v ansible-playbook)" ]]; then
  SETUP_METHOD="Ansible (recommended): \`ansible-playbook playbook-dev_setup.yml\`"
else
  SETUP_METHOD="Shell script: \`./bootstrap.sh\`"
fi

PR_BODY="Rolls out standard GitHub workflows, pre-commit profiles, and helper scripts from the org \`.github\` repo.\n\n**Profiles**: $PROFILES_CANONICAL\n\n**To set up pre-commit hooks locally:**\n\n1. Copy the setup playbook/script to your repo (included in this PR): playbook-dev_setup.yml or bootstrap.sh\n2. Customize the \`profiles\` list in your chosen file\n3. Run the setup:\n   $SETUP_METHOD\n\nBoth options do the same thing — choose whichever is available in your environment.\n\nAfter setup, hooks will run automatically on commit/push/commit-msg. See the org \`.github\` repo README for details."
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

WORKFLOW_FILES=("$WORKFLOW_SRC_DIR"/*.yml)
if (( ${#WORKFLOW_FILES[@]} == 0 )); then
  echo "ERROR: no workflow templates found in: $WORKFLOW_SRC_DIR"
  exit 1
fi

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

  # If --repo was specified, skip everything else
  if [[ -n "$ONLY_REPO" && "$REPO_NAME" != "$ONLY_REPO" ]]; then
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

  PROFILES_DEST_DIR="$CLONE_DIR/pre-commit-profiles"
  SCRIPTS_DEST_DIR="$CLONE_DIR/scripts"

  DEFAULT_BRANCH=$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name')

  mkdir -p "$DEST_DIR"

  # Copy all workflows dynamically
  for src in $WORKFLOW_FILES; do
    cp "$src" "$DEST_DIR/"
  done

  # Copy selected pre-commit profiles
  mkdir -p "$PROFILES_DEST_DIR"
  for src in $PROFILE_FILES; do
    cp "$src" "$PROFILES_DEST_DIR/"
  done

  # Copy helper scripts if directory exists
  if [[ -d "$SCRIPTS_SRC_DIR" ]]; then
    HELPER_SCRIPTS=("$SCRIPTS_SRC_DIR"/*.sh)
    if (( ${#HELPER_SCRIPTS[@]} > 0 )); then
      mkdir -p "$SCRIPTS_DEST_DIR"
      for src in $HELPER_SCRIPTS; do
        cp "$src" "$SCRIPTS_DEST_DIR/"
        chmod +x "$SCRIPTS_DEST_DIR/${src:t}"
      done
    fi
  fi

  # Copy setup templates to repo root (playbook and shell script options)
  if [[ -d "$TEMPLATES_SRC_DIR" ]]; then
    for template_file in playbook-dev_setup.yml bootstrap.sh; do
      if [[ -f "$TEMPLATES_SRC_DIR/$template_file" ]]; then
        cp "$TEMPLATES_SRC_DIR/$template_file" "$CLONE_DIR/$template_file"
        [[ "$template_file" == "bootstrap.sh" ]] && chmod +x "$CLONE_DIR/$template_file"
      fi
    done
  fi

  # Copy config files (based on selected profiles)
  for config_name in $CONFIG_FILES_TO_DEPLOY; do
    config_src="$SCRIPT_DIR/$config_name"
    if [[ -f "$config_src" ]]; then
      config_dest="$CLONE_DIR/$config_name"
      mkdir -p "${config_dest:h}"
      cp "$config_src" "$config_dest"
    fi
  done

  if git -C "$CLONE_DIR" diff --quiet -- .github/workflows pre-commit-profiles scripts playbook-dev_setup.yml bootstrap.sh git-hook-config; then
    echo "  ✓ shared workflows/hooks/configs already present — skipping"
    ALREADY_DONE+=("$REPO_NAME")
    continue
  fi

  if $DRY_RUN; then
    echo "  [dry-run] [profiles: $PROFILES_CANONICAL] would sync workflows+profiles+scripts+configs and open PR → $PR_BRANCH → $DEFAULT_BRANCH"
    WOULD_CREATE+=("$REPO_NAME")
    continue
  fi

  pushd "$CLONE_DIR" >/dev/null

  git checkout -b "$PR_BRANCH"
  git add .github/workflows
  [[ -d pre-commit-profiles ]] && git add pre-commit-profiles
  [[ -d scripts ]] && git add scripts
  [[ -f playbook-dev_setup.yml ]] && git add playbook-dev_setup.yml
  [[ -f bootstrap.sh ]] && git add bootstrap.sh
  for config_name in $CONFIG_FILES_TO_DEPLOY; do
    [[ -f "$config_name" ]] && git add "$config_name"
  done
  git commit -m "$PR_TITLE"

  if ! git push origin "$PR_BRANCH" --quiet 2>/dev/null; then
    echo "  ✗ push failed — skipping PR creation"
    popd >/dev/null
    FAILED+=("$REPO_NAME (push failed)")
    continue
  fi

  PR_URL=$(gh pr create \
    --title  "$PR_TITLE" \
    --body   "$(printf '%b' "$PR_BODY")" \
    --base   "$DEFAULT_BRANCH" \
    --head   "$PR_BRANCH")

  popd >/dev/null

  echo "  ✓ PR created: $PR_URL"
  CREATED+=("$REPO_NAME|$PR_URL")
done

# ── Summary ────────────────────────────────────────────────────────────────────
echo "\n══════════════════════════════════════════════════════════"
$DRY_RUN && echo "  DRY RUN — no changes were made." || echo "  Done."
echo "  Profiles       : $PROFILES_CANONICAL"
echo "  Config files   : ${CONFIG_FILES_TO_DEPLOY[*]}"
echo ""
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
  for entry in $CREATED; do echo "    • ${entry%%|*}: ${entry##*|}"; done
fi

if (( ${#FAILED[@]} > 0 )); then
  echo "\n  Failures:"
  for r in $FAILED; do echo "    • $r"; done
fi
echo "══════════════════════════════════════════════════════════"
