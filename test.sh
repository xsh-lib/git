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

echo "==> git/hub/account-for-email (hit on first pair)"
[[ $(XSH_GIT_HUB_ACCOUNT_MAP="a@b=alice c@d=bob" \
        _xsh git/hub/account-for-email a@b) == alice ]]

echo "==> git/hub/account-for-email (hit on later pair)"
[[ $(XSH_GIT_HUB_ACCOUNT_MAP="a@b=alice c@d=bob" \
        _xsh git/hub/account-for-email c@d) == bob ]]

echo "==> git/hub/account-for-email (miss returns 1)"
rc=0
XSH_GIT_HUB_ACCOUNT_MAP="a@b=alice" \
    _xsh git/hub/account-for-email nope@x >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]]

echo "==> git/hub/account-for-email (empty map returns 1)"
rc=0
XSH_GIT_HUB_ACCOUNT_MAP="" \
    _xsh git/hub/account-for-email anything@x >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]]

echo "==> git/hub/account-for-email (account value containing '=')"
[[ $(XSH_GIT_HUB_ACCOUNT_MAP="weird@e=acct=with=eq" \
        _xsh git/hub/account-for-email weird@e) == "acct=with=eq" ]]


# -----------------------------------------------------------------------------
# git/hub/account-for-repo
# -----------------------------------------------------------------------------

echo "==> git/hub/account-for-repo (derives from local repo's user.email)"
tmprepo=$(mktemp -d "${TMPDIR:-/tmp}/xsh-git-test.XXXXXXXX")
trap 'rm -rf "$tmprepo"' EXIT
(
    cd "$tmprepo"
    git init -q
    git config user.email "a@b"
    export XSH_GIT_HUB_ACCOUNT_MAP="a@b=alice"
    [[ $(_xsh git/hub/account-for-repo) == alice ]]
)

echo "==> git/hub/account-for-repo (outside repo / no user.email returns 1)"
rc=0
(
    cd "${TMPDIR:-/tmp}"
    GIT_CONFIG_NOSYSTEM=1 HOME="$tmprepo" \
        _xsh git/hub/account-for-repo >/dev/null 2>&1
) || rc=$?
[[ $rc -eq 1 ]]

echo "==> git/hub/account-for-repo (unmapped email returns 1)"
rc=0
(
    cd "$tmprepo"
    git config user.email "unknown@x"
    XSH_GIT_HUB_ACCOUNT_MAP="a@b=alice" \
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

# Happy path needs a logged-in gh account; opt-in only.
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
