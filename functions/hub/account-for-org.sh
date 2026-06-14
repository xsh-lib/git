#? Description:
#?   Print the gh account name that defaults for the given GitHub org.
#?
#?   The data is read from the environment variable `XSH_GIT_HUB_ACCOUNTS`,
#?   a whitespace-separated list of records, each in the format:
#?
#?     <account>:<email>:<org>[,<org>...]
#?
#?   For details on the record format, see `xsh help git/hub/account-for-email`.
#?
#?   First match wins: if two records both list <ORG> in their orgs field,
#?   the one earlier in XSH_GIT_HUB_ACCOUNTS is returned. The other account
#?   stays reachable via the explicit SSH alias URL
#?   `git@github-<account>:<ORG>/<repo>.git`.
#?
#?   This util is the org-lookup primitive; it does not touch the repo or
#?   gh. Records whose orgs field is empty are skipped.
#?
#? Usage:
#?   @account-for-org <ORG>
#?
#? Options:
#?   <ORG>   The GitHub org name (e.g. `HyperSolidAPP`).
#?
#? Return:
#?   0 on hit, with the account name printed to stdout.
#?   1 on miss, with no output.
#?
#? Example:
#?   @account-for-org HyperSolidAPP
#?
function account-for-org () {
    declare org=${1:?missing ORG}
    declare record r_account r_orgs_csv o
    for record in $XSH_GIT_HUB_ACCOUNTS; do
        IFS=':' read -r r_account _ r_orgs_csv <<< "$record"
        [[ -z $r_orgs_csv ]] && continue
        # split the CSV on comma. `read -a` is bash-only (zsh's read has no -a,
        # and -A differs); org names never contain spaces, so replacing commas
        # with spaces and word-splitting is portable across bash and zsh.
        # shellcheck disable=SC2086
        for o in ${r_orgs_csv//,/ }; do
            if [[ $o == "$org" ]]; then
                printf '%s\n' "$r_account"
                return 0
            fi
        done
    done
    return 1
}
