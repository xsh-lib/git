#? Description:
#?   Run a command with a specific gh account active, isolated from every
#?   other shell session.
#?
#?   The active-account state lives in ~/.config/gh/hosts.yml, which is
#?   shared by every terminal and every credential-helper invocation
#?   system-wide. Calling `gh auth switch` directly therefore impacts every
#?   concurrent session, even momentarily.
#?
#?   This util avoids that entirely. For each invocation it:
#?     1. Creates a private mode-700 tempdir.
#?     2. Copies ~/.config/gh into it.
#?     3. Points GH_CONFIG_DIR at the copy.
#?     4. Runs `gh auth switch -u <account>` against the copy.
#?     5. Runs the wrapped command with GH_CONFIG_DIR still pointed at the copy.
#?     6. Deletes the copy on exit.
#?
#?   The real ~/.config/gh is never mutated. Concurrent sessions are
#?   unaffected. No lockfile is needed because there is no shared resource
#?   being contended.
#?
#?   Works for `git push/pull/fetch` because gh registers itself as a
#?   credential helper that reads GH_CONFIG_DIR from the environment, and
#?   child git processes inherit it.
#?
#? Dependency:
#?   1. gh (GitHub CLI) — https://cli.github.com
#?   2. xsh git/hub/account-for-repo (only when -u is omitted)
#?
#? Usage:
#?   @run [-u ACCOUNT] -- COMMAND [ARGS...]
#?
#? Options:
#?   [-u ACCOUNT]   The gh account to activate. If omitted, derived from
#?                  the current repo via @account-for-repo.
#?
#?   --             Mandatory separator before the command to run. Allows
#?                  the wrapped command to use its own flags without
#?                  confusing this util's option parser.
#?
#?   COMMAND ...    The command to run with the chosen account active.
#?
#? Example:
#?   @run -- git push origin main
#?   @run -- gh pr create --fill
#?   @run -u alice-corp -- gh pr list
#?
#? @subshell
#?
function run () {
    declare account=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u) account=$2; shift 2 ;;
            --) shift; break ;;
            -*) printf 'hub-run: unknown option %s\n' "$1" >&2; return 2 ;;
            *)  break ;;
        esac
    done

    if [[ $# -eq 0 ]]; then
        printf 'hub-run: no command given (usage: @run [-u ACCOUNT] -- CMD [ARGS...])\n' >&2
        return 2
    fi

    if [[ -z $account ]]; then
        account=$(xsh git/hub/account-for-repo) || return 1
    fi

    declare src_dir tmpdir
    src_dir=${GH_CONFIG_DIR:-$HOME/.config/gh}
    if [[ ! -d $src_dir ]]; then
        printf 'hub-run: gh config dir not found at %s\n' "$src_dir" >&2
        return 1
    fi

    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/xsh-git-hub-run.XXXXXXXX") || return 1
    chmod 700 "$tmpdir"
    trap 'rm -rf "$tmpdir"' EXIT

    cp -R "$src_dir/." "$tmpdir/" || return 1
    export GH_CONFIG_DIR=$tmpdir

    if ! gh auth switch -u "$account" >/dev/null 2>&1; then
        printf "hub-run: 'gh auth switch -u %s' failed — is the account logged in? (try 'gh auth status')\n" "$account" >&2
        return 1
    fi

    "$@"
}
