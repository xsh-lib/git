#? Description:
#?   Print the gh account name associated with the given email.
#?
#?   The data is read from the environment variable `XSH_GIT_HUB_ACCOUNTS`,
#?   a whitespace-separated list of records, each in the format:
#?
#?     <account>:<email>:<org>[,<org>...]
#?
#?   - <account>  gh account name; required.
#?   - <email>    email tied to this account via ~/.gitconfig includeIf
#?                rules. May be empty for bot-style accounts with no
#?                per-directory email binding.
#?   - <org>      GitHub org for which this account is the default. Zero
#?                or more, comma-separated. Used by `account-for-org` and
#?                `git/hub/ssh`; ignored here.
#?
#?   Example:
#?
#?     export XSH_GIT_HUB_ACCOUNTS="alice:alice@example.com:alice,xsh-alice bob:bob@corp.io:bob-corp"
#?
#?   This util is the email-lookup primitive; it does not touch the repo
#?   or gh. Records whose email field is empty are skipped.
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
    declare record r_account r_email
    for record in $XSH_GIT_HUB_ACCOUNTS; do
        IFS=':' read -r r_account r_email _ <<< "$record"
        if [[ -n $r_email && $r_email == "$email" ]]; then
            printf '%s\n' "$r_account"
            return 0
        fi
    done
    return 1
}
