# API-Key-Git-Scrubber

A small bash script that removes a leaked secret (an API key, token, etc.) from the **entire history** of a Git repository by exact string match. It rewrites file contents, commit messages, and tag messages, then force-pushes the cleaned history.

It's a wrapper around [`git-filter-repo`](https://github.com/newren/git-filter-repo) that handles the fiddly parts: a fresh mirror clone, a temp rules file kept outside your repo, hidden key input, verification checks, and a confirmation prompt before anything is pushed.

> **Rotate the key first.** Once a secret has been committed, treat it as compromised. Rewriting history removes it from the repo, but it can't un-expose copies that already exist (clones, forks, caches). Revoking or rotating the key with the provider is the step that actually protects you.

## Requirements

- bash, git, and Python 3
- [`git-filter-repo`](https://github.com/newren/git-filter-repo)
  - macOS: `brew install git-filter-repo`
  - Other: `pip install --user git-filter-repo` (the script tries this automatically if it's missing)
- Push access to the repo (with force pushes allowed on the branches you're rewriting)

## Usage

1. Open `clean.sh` and set `REPO_URL` to your repository:

   ```bash
   REPO_URL="https://github.com/YOU/YOUR-REPO.git"   # or git@github.com:YOU/YOUR-REPO.git
   ```

2. Run it:

   ```bash
   bash clean.sh
   ```

3. At the `Paste the leaked key:` prompt, paste the secret and press Enter. Input is hidden, so nothing will appear on screen. The key is never written into the script, your shell history, or your repo.

4. The script rewrites history and runs three checks (file contents, commit messages, tag messages). **All three should print nothing.**

5. If they're empty, type `yes` to force-push branches and tags. Anything else aborts without pushing.

## What it does

1. Prompts for the secret (hidden input) and writes a replacement rule to a temp file outside any repo.
2. Makes a fresh `git clone --mirror` in a temp directory, so every branch and tag is included and your working copy isn't touched.
3. Runs `git filter-repo --replace-text` and `--replace-message` to replace the secret with an empty string everywhere it appears.
4. Searches the rewritten history for the secret to confirm it's gone.
5. On your confirmation, re-adds the remote and force-pushes `refs/heads/*` and `refs/tags/*`.
6. Deletes the temp files and clone on exit.

To leave a visible marker instead of an empty string, change this line:

```bash
printf '%s==>\n' "$KEY" > "$RULES"          # replaces with nothing
printf '%s==>REMOVED\n' "$KEY" > "$RULES"   # replaces with REMOVED
```

## Limitations

- **Exact matches only.** Base64-encoded, URL-encoded, or line-split versions of the secret won't be found.
- **Contents and messages only.** Secrets in file names, branch names, tag names, or author fields aren't rewritten.
- **Copies you don't control.** Existing clones, forks, and GitHub's cached commit views may still hold the original history. Pull request refs (`refs/pull/*`) can also linger on GitHub and are not pushed by this script.
- **Signatures break.** Rewriting invalidates signed commits and tags.
- **Every hash after the first affected commit changes.** Anyone with an existing clone needs to re-clone.

## After running

1. Re-clone the repo fresh and confirm the secret is gone:

   ```bash
   git log --all -S'THE_SECRET' --oneline
   ```

2. Scan the full history for anything else you missed:

   ```bash
   gitleaks detect --source . --log-opts="--all"
   ```

3. Delete or re-clone every other local copy of the old history.
4. Make sure the secret has been rotated or restricted with its provider.
5. Only then make the repo public, if that was the goal.

## Preventing the next leak

- Keep secrets out of tracked files: use environment variables, or a config file listed in `.gitignore` plus a committed `.example` template.
- Add a secret scanner such as [gitleaks](https://github.com/gitleaks/gitleaks) or [trufflehog](https://github.com/trufflesecurity/trufflehog) as a pre-commit hook or CI step.
- Enable GitHub's secret scanning and push protection if they're available for your repo.

## Related tools

- [`git-filter-repo`](https://github.com/newren/git-filter-repo): the engine this script wraps, and the tool GitHub's docs recommend for removing sensitive data.
- [BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/): an alternative history-rewriting tool.

## Disclaimer

This script rewrites and force-pushes Git history, which is destructive and can't be undone. Make sure you have a backup and understand what it does before running it against a repo other people depend on. Provided as-is, with no warranty.
