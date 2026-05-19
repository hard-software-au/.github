#!/bin/bash
# Bootstrap pre-commit hooks setup (template)
#
# Copy this to your repo root as bootstrap.sh and customize the PROFILES variable.
# Then commit it and document the setup command in your README.md:
#
#   ./bootstrap.sh
#
# This script will:
#   1. Check for system prerequisites (gitleaks, Node.js)
#   2. Run ./scripts/bootstrap-hooks.sh with your configured profiles
#   3. Create local .venv with all tool dependencies
#   4. Configure git hooks automatically

set -euo pipefail

# ────────────────────────────────────────────────────────────────────────────
# CUSTOMIZE THIS: set your repo's profiles
# Options: baseline, python, node, ruby, ansible
# Examples:
#   PROFILES="baseline python"
#   PROFILES="baseline ansible"
#   PROFILES="baseline python ruby"
PROFILES="baseline"
# ────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check for gitleaks (system prerequisite)
if ! command -v gitleaks &>/dev/null; then
    log_warn "gitleaks not found. Please install it:"
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "  brew install gitleaks"
    else
        echo "  sudo apt-get install gitleaks  # Debian/Ubuntu"
        echo "  yum install gitleaks            # RHEL/CentOS"
    fi
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for Node.js if node/baseline profile is used
if [[ "$PROFILES" == *"node"* ]] || [[ "$PROFILES" == *"baseline"* ]]; then
    if ! command -v npm &>/dev/null; then
        log_error "npm not found, but node/baseline profile requires Node.js"
        if [[ "$(uname)" == "Darwin" ]]; then
            echo "Install with: brew install node"
        else
            echo "Install with: apt-get install nodejs  # Debian/Ubuntu"
        fi
        exit 1
    fi
fi

# Check if bootstrap-hooks.sh exists
if [[ ! -f "$SCRIPT_DIR/scripts/bootstrap-hooks.sh" ]]; then
    log_error "scripts/bootstrap-hooks.sh not found"
    log_error "This script expects to be run from a repo that has been rolled out via rollout-workflows.sh"
    exit 1
fi

# Make bootstrap script executable
chmod +x "$SCRIPT_DIR/scripts/bootstrap-hooks.sh"

# Run bootstrap-hooks.sh
log_info "Setting up pre-commit hooks with profiles: $PROFILES"
cd "$SCRIPT_DIR"
./scripts/bootstrap-hooks.sh $PROFILES

log_info "✓ Setup complete!"
echo ""
echo "Hooks are now active and will run on:"
echo "  • git commit (pre-commit stage)"
echo "  • git push (pre-push stage)"
echo "  • commit message validation (commit-msg stage)"
echo ""
echo "To manually run all checks:"
echo "  source .venv/bin/activate"
echo "  pre-commit run --all-files"
echo "  deactivate"
