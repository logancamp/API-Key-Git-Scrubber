#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/logancamp/todo.git"   # SSH alternative: git@github.com:logancamp/todo.git

# Prompt for the key (hidden input, not saved to shell history)
read -rsp "Paste the leaked key: " KEY; echo
[ -n "$KEY" ] || { echo "Key is empty, aborting."; exit 1; }

# Install git-filter-repo if needed (on macOS, `brew install git-filter-repo` is more reliable)
command -v git-filter-repo >/dev/null || pip install --user git-filter-repo

# Work in temp locations outside any repo; clean up on exit
WORK=$(mktemp -d)
RULES=$(mktemp)
trap 'rm -rf "$WORK" "$RULES"' EXIT
printf '%s==>\n' "$KEY" > "$RULES"    # empty replacement; use ==>REMOVED for a placeholder

# Fresh mirror clone so every branch and tag is included
git clone --mirror "$REPO_URL" "$WORK/repo.git"
cd "$WORK/repo.git"

# Rewrite file contents, commit messages, and tag messages
git filter-repo --replace-text "$RULES" --replace-message "$RULES"

# Verify: each check should print nothing
echo "== Checking file contents in all history =="
git log --all -S"$KEY" --oneline
echo "== Checking commit messages =="
git log --all --fixed-strings --grep="$KEY" --oneline
echo "== Checking tag/ref messages =="
git for-each-ref --format='%(refname) %(contents)' | grep -F -- "$KEY" || true

read -rp "If all three checks above were empty, push? (yes/no) " OK
[ "$OK" = "yes" ] || { echo "Aborted, nothing pushed."; exit 1; }

# filter-repo drops the remote, so re-add it, then force push branches and tags only
git remote add origin "$REPO_URL"
git push --force origin 'refs/heads/*' 'refs/tags/*'

echo "Done. Now re-clone any other copies of the old history."
