#? Description:
#?   Print the gh account name that should be used for the current repo.
#?
#?   The account is derived from `git config user.email` and looked up via
#?   `@account-for-email`. `~/.gitconfig` typically has `includeIf "gitdir:..."`
#?   rules that set user.email per directory tree, so this is the
#?   authoritative signal — not the globally-active gh account.
#?
#? Dependency:
#?   1. xsh git/hub/account-for-email
#?   2. The env var XSH_GIT_HUB_ACCOUNT_MAP must contain a mapping for the
#?      repo's email. See `xsh help /git/hub/account-for-email`.
#?
#? Usage:
#?   @account-for-repo
#?
#? Return:
#?   0 on hit, with the account name printed to stdout.
#?   1 if not in a repo, user.email unset, or email not mapped.
#?
#? Example:
#?   (inside ~/Workspace/GitHub/your-org/some-repo)
#?   @account-for-repo
#?
function account-for-repo () {
    declare email account
    email=$(git config user.email 2>/dev/null)
    if [[ -z $email ]]; then
        printf 'account-for-repo: not in a git repo, or user.email unset\n' >&2
        return 1
    fi
    if ! account=$(xsh git/hub/account-for-email "$email"); then
        printf 'account-for-repo: no gh account mapped for %s\n' "$email" >&2
        printf '  add "<email>=<account>" to XSH_GIT_HUB_ACCOUNT_MAP\n' >&2
        return 1
    fi
    printf '%s\n' "$account"
}
