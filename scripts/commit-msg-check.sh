#!/bin/bash
# commit-msg-check.sh
# Validates commit message format against convention:
#   - First line: Conventional Commits subject (< 50 chars)
#     format: <type>(<optional-scope>)!: <description>
#     example: feat(auth): add SSO callback handling
#   - Blank line after first line (if body present)
#   - Body lines: < 72 chars
#
# Usage: commit-msg-check.sh
# Called by pre-commit via commit-msg hook (passes commit message file as $1)

COMMIT_MSG_FILE="${1:-.git/COMMIT_EDITMSG}"

# Use C locale for deterministic character class/range behavior in checks.
export LC_ALL=C

if [[ ! -f "$COMMIT_MSG_FILE" ]]; then
    echo "ERROR: commit message file not found: $COMMIT_MSG_FILE"
    exit 1
fi

# Read commit message
MSG=$(cat "$COMMIT_MSG_FILE")

# Skip merge commits and rebases
if echo "$MSG" | head -1 | grep -qE '^(Merge|Revert)'; then
    exit 0
fi

FIRST_LINE=$(echo "$MSG" | head -1)
FIRST_LINE_LEN=${#FIRST_LINE}

# Check 1: First line must be < 50 chars
if (( FIRST_LINE_LEN >= 50 )); then
    echo "ERROR: first line is too long ($FIRST_LINE_LEN chars, max 50)"
    echo "  $FIRST_LINE"
    exit 1
fi

# Check 2: First line must not be empty
if [[ -z "$FIRST_LINE" ]]; then
    echo "ERROR: commit message is empty"
    exit 1
fi

# Check 3: Conventional Commits subject format
CONVENTIONAL_PATTERN='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-zA-Z0-9._/-]+\))?(!)?: .+'
if [[ ! "$FIRST_LINE" =~ $CONVENTIONAL_PATTERN ]]; then
    echo "ERROR: commit subject must follow Conventional Commits format"
    echo "  Required: <type>(<optional-scope>)!: <description>"
    echo "  Allowed types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert"
    echo "  Example: feat(auth): add SSO callback handling"
    echo "  $FIRST_LINE"
    exit 1
fi

# Check 4: First line should not end with a period
if [[ "$FIRST_LINE" == *. ]]; then
    echo "WARNING: first line should not end with a period (ignored but not recommended)"
fi

# Check 5: If there's a body, second line must be blank
if (( $(echo "$MSG" | wc -l) > 1 )); then
    SECOND_LINE=$(echo "$MSG" | sed -n '2p')
    if [[ -n "$SECOND_LINE" ]]; then
        echo "ERROR: second line must be blank (separates subject from body)"
        echo "  Line 1: $FIRST_LINE"
        echo "  Line 2: $SECOND_LINE"
        exit 1
    fi
    
    # Check 6: Body lines must be < 72 chars
    LINE_NUM=3
    while IFS= read -r line; do
        if [[ $LINE_NUM -gt 2 ]]; then
            LINE_LEN=${#line}
            if (( LINE_LEN >= 72 && -n "$line" )); then
                echo "WARNING: line $LINE_NUM is $LINE_LEN chars (recommended max 72)"
            fi
        fi
        (( LINE_NUM++ ))
    done <<< "$MSG"
fi

exit 0
