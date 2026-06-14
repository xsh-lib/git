#!/bin/bash
#
# Smoke tests for xsh-lib/git utilities. Mirrors xsh-lib/core/test.sh: plain
# bash assertions, no external test framework.
#
# Usage:
#   xsh load xsh-lib/git    # one-time
#   bash test.sh            # tests the loaded copy
#
# Local dev iteration against an unpushed working copy:
#   xsh lib-dev-manager link xsh-lib/git /path/to/workspace
#   XSH_DEV=1 bash test.sh
#
# Tests that touch the network or require an authenticated `gh` are skipped
# unless XSH_GIT_TEST_NETWORK=1 is set explicitly.
#

# Make the `xsh` function available when run as a child process. Under bash it
# is inherited as an exported function (no-op here); zsh cannot export functions,
# so a child `zsh test.sh` sources ~/.xshrc to define xsh as a real zsh function
# (otherwise it would only see the bin/xsh shim, which runs bash).
if ! type xsh 2>/dev/null | grep -q 'function'; then
    # shellcheck source=/dev/null
    . ~/.xshrc
fi

set -e -o pipefail

# xsh's __xsh_clean unsets XSH_DEV on every RETURN trap, so a script that makes
# multiple xsh calls only gets dev-mode for the first one. Capture the initial
# value once and re-apply it via a wrapper.
_TEST_XSH_DEV="${XSH_DEV-}"
_xsh () { XSH_DEV="$_TEST_XSH_DEV" xsh "$@"; }


echo "==> xsh list /"
_xsh list /


# -----------------------------------------------------------------------------
# git/hub/account-for-email
# -----------------------------------------------------------------------------
#
# Records: <account>:<email>:<org>[,<org>...]
# email-lookups skip records with empty email field.
#

echo "==> account-for-email (hit on first record)"
[[ $(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:a-org,b-org bob:bob@y:c-org" \
        _xsh git/hub/account-for-email alice@x) == alice ]]

echo "==> account-for-email (hit on later record)"
[[ $(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:a-org bob:bob@y:c-org" \
        _xsh git/hub/account-for-email bob@y) == bob ]]

echo "==> account-for-email (record with no orgs still matches)"
[[ $(XSH_GIT_HUB_ACCOUNTS="alice:alice@x: bob:bob@y:" \
        _xsh git/hub/account-for-email bob@y) == bob ]]

echo "==> account-for-email (records with empty email don't accidentally match a real lookup)"
rc=0
XSH_GIT_HUB_ACCOUNTS="bot::a-org alice:alice@x:b-org" \
    _xsh git/hub/account-for-email some@unmapped >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]]

echo "==> account-for-email (miss returns 1)"
rc=0
XSH_GIT_HUB_ACCOUNTS="alice:alice@x:a-org" \
    _xsh git/hub/account-for-email nope@x >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]]

echo "==> account-for-email (empty env var returns 1)"
rc=0
XSH_GIT_HUB_ACCOUNTS="" \
    _xsh git/hub/account-for-email anything@x >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]]


# -----------------------------------------------------------------------------
# git/hub/account-for-org
# -----------------------------------------------------------------------------

echo "==> account-for-org (hit on single-org account)"
[[ $(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:a-org" \
        _xsh git/hub/account-for-org a-org) == alice ]]

echo "==> account-for-org (hit on later org in a multi-org account)"
[[ $(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:a-org,b-org,c-org" \
        _xsh git/hub/account-for-org c-org) == alice ]]

echo "==> account-for-org (first-match-wins across records)"
[[ $(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:shared-org bob:bob@y:shared-org" \
        _xsh git/hub/account-for-org shared-org) == alice ]]

echo "==> account-for-org (record with no orgs is skipped)"
rc=0
XSH_GIT_HUB_ACCOUNTS="bot:bot@x: alice:alice@y:a-org" \
    _xsh git/hub/account-for-org nope-org >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]]

echo "==> account-for-org (miss returns 1)"
rc=0
XSH_GIT_HUB_ACCOUNTS="alice:alice@x:a-org" \
    _xsh git/hub/account-for-org other-org >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]]


# -----------------------------------------------------------------------------
# git/hub/account-for-repo
# -----------------------------------------------------------------------------

echo "==> account-for-repo (derives from local repo's user.email)"
tmprepo=$(mktemp -d "${TMPDIR:-/tmp}/xsh-git-test.XXXXXXXX")
trap 'rm -rf "$tmprepo"; rm -rf "$tmpbin"' EXIT
(
    cd "$tmprepo"
    git init -q
    git config user.email "alice@x"
    export XSH_GIT_HUB_ACCOUNTS="alice:alice@x:a-org"
    [[ $(_xsh git/hub/account-for-repo) == alice ]]
)

echo "==> account-for-repo (outside repo / no user.email returns 1)"
rc=0
(
    cd "${TMPDIR:-/tmp}"
    GIT_CONFIG_NOSYSTEM=1 HOME="$tmprepo" \
        _xsh git/hub/account-for-repo >/dev/null 2>&1
) || rc=$?
[[ $rc -eq 1 ]]

echo "==> account-for-repo (unmapped email returns 1)"
rc=0
(
    cd "$tmprepo"
    git config user.email "unknown@x"
    XSH_GIT_HUB_ACCOUNTS="alice:alice@x:a-org" \
        _xsh git/hub/account-for-repo >/dev/null 2>&1
) || rc=$?
[[ $rc -eq 1 ]]


# -----------------------------------------------------------------------------
# git/hub/run
# -----------------------------------------------------------------------------

echo "==> git/hub/run (no command after -- returns 2)"
rc=0
_xsh git/hub/run -u dummy -- >/dev/null 2>&1 || rc=$?
[[ $rc -eq 2 ]]

echo "==> git/hub/run (unknown option returns 2)"
rc=0
_xsh git/hub/run --bogus -- echo x >/dev/null 2>&1 || rc=$?
[[ $rc -eq 2 ]]

echo "==> git/hub/run (missing gh config dir returns 1)"
rc=0
GH_CONFIG_DIR="${TMPDIR:-/tmp}/xsh-git-no-such-dir-$$" \
    _xsh git/hub/run -u dummy -- echo x >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]]


# -----------------------------------------------------------------------------
# git/hub/ssh (scripts/hub/ssh.sh)
# -----------------------------------------------------------------------------
#
# Strategy: put a fake `ssh` on PATH that echoes its argv. The wrapper
# does exec ssh, so when invoked under the fake PATH it prints what it
# would have run. The script lives under the dev-linked workspace at
# ~/.xsh/lib-dev/git/scripts/hub/ssh.sh (or as the symlink target after
# `xsh imports git/hub/ssh`).
#
# Locate the script via XSH_DEV_HOME (dev mode) or the canonical install
# path. Tests are run from this repo, so the dev-linked path matches.
#

if [[ -n $_TEST_XSH_DEV ]]; then
    SSH_WRAPPER="${XSH_DEV_HOME:-$HOME/.xsh/lib-dev}/git/scripts/hub/ssh.sh"
else
    SSH_WRAPPER="${XSH_LIB_HOME:-$HOME/.xsh/lib}/git/scripts/hub/ssh.sh"
fi

if [[ ! -x $SSH_WRAPPER ]]; then
    echo "==> git/hub/ssh (skipped — script not found at $SSH_WRAPPER)"
else
    # Fake ssh on PATH.
    tmpbin=$(mktemp -d "${TMPDIR:-/tmp}/xsh-git-fakebin.XXXXXXXX")
    cat > "$tmpbin/ssh" <<'EOF'
#!/bin/sh
printf 'FAKE-SSH'
for a; do printf ' %s' "$a"; done
printf '\n'
EOF
    chmod +x "$tmpbin/ssh"

    _ssh_test () {
        # Args after `--`: the argv to pass through the wrapper.
        # Stdout: the fake-ssh line, with absolute key paths normalised
        # so assertions can use ~ as a placeholder.
        PATH="$tmpbin:$PATH" XSH_GIT_HUB_ACCOUNTS="$XSH_GIT_HUB_ACCOUNTS" \
            "$SSH_WRAPPER" "$@" \
            | sed "s|$HOME|~|g"
    }

    echo "==> git/hub/ssh (org mapped → -i with right key prepended)"
    out=$(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:HyperSolidAPP" \
        _ssh_test git@github.com "git-upload-pack 'HyperSolidAPP/foo.git'")
    [[ $out == "FAKE-SSH -i ~/.ssh/github-alice -o IdentitiesOnly=yes git@github.com git-upload-pack 'HyperSolidAPP/foo.git'" ]]

    echo "==> git/hub/ssh (receive-pack also recognized)"
    out=$(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:HyperSolidAPP" \
        _ssh_test git@github.com "git-receive-pack 'HyperSolidAPP/foo.git'")
    [[ $out == "FAKE-SSH -i ~/.ssh/github-alice -o IdentitiesOnly=yes git@github.com git-receive-pack 'HyperSolidAPP/foo.git'" ]]

    echo "==> git/hub/ssh (org unmapped → pass-through, no -i)"
    out=$(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:OtherOrg" \
        _ssh_test git@github.com "git-upload-pack 'HyperSolidAPP/foo.git'")
    [[ $out == "FAKE-SSH git@github.com git-upload-pack 'HyperSolidAPP/foo.git'" ]]

    echo "==> git/hub/ssh (non-github host → pass-through)"
    out=$(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:HyperSolidAPP" \
        _ssh_test git@github-alex-hypersolid "git-upload-pack 'HyperSolidAPP/foo.git'")
    [[ $out == "FAKE-SSH git@github-alex-hypersolid git-upload-pack 'HyperSolidAPP/foo.git'" ]]

    echo "==> git/hub/ssh (no pack command → pass-through)"
    out=$(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:HyperSolidAPP" \
        _ssh_test git@github.com "some-other-command")
    [[ $out == "FAKE-SSH git@github.com some-other-command" ]]

    echo "==> git/hub/ssh (first-match-wins for ambiguous org)"
    out=$(XSH_GIT_HUB_ACCOUNTS="alice:alice@x:shared bob:bob@y:shared" \
        _ssh_test git@github.com "git-upload-pack 'shared/foo.git'")
    [[ $out == "FAKE-SSH -i ~/.ssh/github-alice -o IdentitiesOnly=yes git@github.com git-upload-pack 'shared/foo.git'" ]]
fi


# -----------------------------------------------------------------------------
# Network-dependent: optional
# -----------------------------------------------------------------------------

if [[ "${XSH_GIT_TEST_NETWORK:-}" == "1" ]] && command -v gh >/dev/null 2>&1; then
    echo "==> git/hub/run (happy path: round-trip gh api user)"
    acct=$(gh auth status 2>&1 \
        | awk '/Logged in to github.com account/{print $7; exit}')
    if [[ -n $acct ]]; then
        [[ $(_xsh git/hub/run -u "$acct" -- gh api user --jq .login) == "$acct" ]]
    else
        echo "    (skipped: no gh account logged in)"
    fi
else
    echo "==> git/hub/run (happy path skipped — set XSH_GIT_TEST_NETWORK=1 to enable)"
fi

echo
echo "All tests passed."
