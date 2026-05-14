#? Description:
#?   Print the gh account name mapped to the given email.
#?
#?   The mapping is read from the environment variable
#?   `XSH_GIT_HUB_ACCOUNT_MAP`, a whitespace-separated list of
#?   "<email>=<account>" pairs. Example:
#?
#?     export XSH_GIT_HUB_ACCOUNT_MAP="alice@example.com=alice bob@corp.io=bob-corp"
#?
#?   This util is the lookup primitive; it does not touch the repo or gh.
#?
#? Usage:
#?   @account-for-email <EMAIL>
#?
#? Options:
#?   <EMAIL>   The email address to look up (typically the value of
#?             `git config user.email` inside a repo).
#?
#? Return:
#?   0 on hit, with the account name printed to stdout.
#?   1 on miss, with no output.
#?
#? Example:
#?   @account-for-email alice@example.com
#?
function account-for-email () {
    declare email=${1:?missing EMAIL}
    declare pair k v
    for pair in $XSH_GIT_HUB_ACCOUNT_MAP; do
        k=${pair%%=*}
        v=${pair#*=}
        if [[ $k == "$email" ]]; then
            printf '%s\n' "$v"
            return 0
        fi
    done
    return 1
}
