#!/bin/bash
#? Description:
#?   SSH wrapper that picks the right per-account key from the repo owner
#?   in the git command line. Invoked by git via core.sshCommand.
#?
#?   For each invocation, the script inspects argv to determine:
#?     1. Is this an SSH to git@github.com? If not, fall through to plain
#?        ssh unchanged. This preserves connections to other hosts
#?        (CodeCommit, EC2, the per-account github-<name> aliases, etc.)
#?     2. Does the git-{upload,receive}-pack command name an org we have
#?        a default account for in $XSH_GIT_HUB_ACCOUNTS? If not, fall
#?        through unchanged — the bare github.com URL will then hit the
#?        loud-fail Host github.com block in ~/.ssh/config, surfacing the
#?        missing routing entry as Permission denied instead of as a
#?        silent wrong-account auth.
#?     3. If yes, exec ssh with `-i ~/.ssh/github-<account>` and
#?        IdentitiesOnly=yes prepended to the original args.
#?
#?   First-match-wins for the org lookup — see
#?   `xsh help git/hub/account-for-org`.
#?
#?   This script is dependency-free at runtime: it does not require xsh to
#?   be loaded in the shell that invokes git. Configure it once via
#?   gitconfig and it works in every git context (terminal, IDE, cron):
#?
#?     git config --global core.sshCommand git-hub-ssh
#?
#?   (After `xsh imports git/hub/ssh`, the script is symlinked into
#?   /usr/local/bin/git-hub-ssh, so the bare name works on PATH.)
#?
#? Dependency:
#?   1. ssh
#?   2. Env var XSH_GIT_HUB_ACCOUNTS — see `xsh help git/hub/account-for-email`.
#?
#? Usage:
#?   git-hub-ssh [SSH_ARGS...]
#?
#?   Not normally invoked by hand. Set as `core.sshCommand` in gitconfig.
#?
#? Example:
#?   git config --global core.sshCommand git-hub-ssh
#?   git clone git@github.com:HyperSolidAPP/foo.git
#?   # → router resolves HyperSolidAPP -> alex-hypersolid -> uses
#?   #   ~/.ssh/github-alex-hypersolid. Cloned origin stays bare.
#?

set -e

# Pass-through for everything not aimed at git@github.com.
is_github=false
for a in "$@"; do
    if [[ $a == git@github.com ]]; then
        is_github=true
        break
    fi
done
$is_github || exec ssh "$@"

# git invokes us with e.g.  git-upload-pack 'HyperSolidAPP/foo.git'
# Extract the org from the first single-quoted path.
org=""
for a in "$@"; do
    case "$a" in
        "git-upload-pack '"*"/"*"'"|"git-receive-pack '"*"/"*"'")
            # strip the wrapping  git-*-pack '<path>'
            tmp=${a#*\'}
            tmp=${tmp%\'}
            org=${tmp%%/*}
            break
            ;;
    esac
done
[[ -z $org ]] && exec ssh "$@"

# Look up org -> account in XSH_GIT_HUB_ACCOUNTS (account:email:orgs).
# First match wins.
account=""
for record in $XSH_GIT_HUB_ACCOUNTS; do
    IFS=':' read -r r_account _ r_orgs_csv <<< "$record"
    [[ -z $r_orgs_csv ]] && continue
    IFS=',' read -ra r_orgs <<< "$r_orgs_csv"
    for o in "${r_orgs[@]}"; do
        if [[ $o == "$org" ]]; then
            account=$r_account
            break 2
        fi
    done
done
[[ -z $account ]] && exec ssh "$@"

exec ssh -i "$HOME/.ssh/github-$account" -o IdentitiesOnly=yes "$@"
