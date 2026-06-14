[![GitHub tag](https://img.shields.io/github/v/tag/xsh-lib/git?sort=date)](https://github.com/xsh-lib/git/tags)
[![GitHub](https://img.shields.io/github/license/xsh-lib/git.svg?style=flat-square)](https://github.com/xsh-lib/git/)
[![GitHub last commit](https://img.shields.io/github/last-commit/xsh-lib/git.svg?style=flat-square)](https://github.com/xsh-lib/git/commits/main)

[![ci-unittest](https://github.com/xsh-lib/git/actions/workflows/ci-unittest.yml/badge.svg)](https://github.com/xsh-lib/git/actions/workflows/ci-unittest.yml)
[![GitHub issues](https://img.shields.io/github/issues/xsh-lib/git.svg?style=flat-square)](https://github.com/xsh-lib/git/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/xsh-lib/git.svg?style=flat-square)](https://github.com/xsh-lib/git/pulls)

# xsh-lib/git

xsh Library - git.

Utilities for working with `git` and GitHub from the shell, packaged as an
[xsh](https://github.com/alexzhangs/xsh) library.

About xsh and its libraries, check out the [xsh document](https://github.com/alexzhangs/xsh).


## Requirements

Tested with bash:

* 5.x and 4.x on Linux (ubuntu-latest in CI)
* 3.2.57 on macOS (macos-latest in CI)

The utilities also run under **zsh** (the default shell on modern macOS); xsh
executes them under zsh's ksh emulation. Tested with zsh 5.x.

This project is still at version `0.x` and should be considered immature.


## Dependency

1. [xsh-lib/core](https://github.com/xsh-lib/core) — should be loaded before
   this library.

   ```bash
   xsh load xsh-lib/core
   ```

2. Some utilities have additional dependencies (e.g. `gh`, `ssh`, `w3m`,
   `collaborator`). See the per-utility help for details.


## Installation

Assume [xsh](https://github.com/alexzhangs/xsh) is already installed.

To load this library into `xsh`:

```bash
xsh load xsh-lib/git
```

The loaded library is referenced by the name `git`.

> The leading slash in an LPUR (e.g. `xsh /string/upper`) is reserved for the
> default library `xsh-lib/core`. For this library, write the lib name
> explicitly: `xsh git/<package>/<util>`.


## Usage

List the utilities exposed by this library:

```bash
xsh list git
```

Get help on any utility:

```bash
xsh help git/<package>/<util>
```


### Available utilities

| Utility                       | Kind     | Purpose                                                                                                          |
|-------------------------------|----------|------------------------------------------------------------------------------------------------------------------|
| `git/hub/account-for-email`   | function | Walk `XSH_GIT_HUB_ACCOUNTS`, return the account whose email matches.                                             |
| `git/hub/account-for-org`     | function | Walk `XSH_GIT_HUB_ACCOUNTS`, return the account that defaults for the given GitHub org. First-match-wins.        |
| `git/hub/account-for-repo`    | function | Derive the account from `git config user.email` in the current repo (delegates to `account-for-email`).          |
| `git/hub/run`                 | function | Run a command with a chosen `gh` account active, isolated from concurrent shell sessions via per-call `GH_CONFIG_DIR`. |
| `git/hub/ssh`                 | script   | SSH wrapper for `core.sshCommand`: picks the right per-account key from the repo owner in git's command line.    |
| `git/hub/collaborator`        | function | Add, remove, or list collaborators of the current GitHub repo. Requires `collaborator` and `w3m`.                |
| `git/rebase-i-in-dumb-term`   | script   | Helper for running `git rebase -i` in dumb terminals.                                                             |


### The account profile env var: `XSH_GIT_HUB_ACCOUNTS`

The `git/hub/*` utilities read a single env var that describes every gh
account you operate. Whitespace-separated records, each with three
colon-separated fields:

```
<account> : <email> : <org>[,<org>...]
```

| Field | Cardinality | Meaning |
|---|---|---|
| `account` | required | gh account name; also the suffix in `~/.ssh/github-<account>`. |
| `email`   | 0..1     | Email tied to this account by `~/.gitconfig` `includeIf` rules. Empty for bot-style accounts with no per-directory binding. |
| `orgs`    | 0..N     | Comma-separated GitHub orgs this account defaults for. Read by `account-for-org` and `git/hub/ssh`. |

Example:

```bash
export XSH_GIT_HUB_ACCOUNTS="alice:alice@example.com:alice,xsh-alice bob:bob@corp.io:bob-corp"
```

If two records list the same org, **first match wins** — the earlier
record's account becomes the default for that org. The other account is
still reachable via the explicit SSH alias URL
`git@github-<account>:<org>/<repo>.git`.


### Multi-`gh`-account workflow

If you operate multiple GitHub accounts simultaneously (e.g. personal +
work) and rely on `~/.gitconfig`'s `includeIf "gitdir:..."` rules to switch
identities per directory tree, this library makes it transparent to push,
PR, and clone against the right account without ever mutating the global
active account in `~/.config/gh`.

1. Map your accounts via the env var described above.

2. Use `git/hub/run` as a transparent wrapper around any `gh` command
   (account auto-derived from the current repo's `user.email`):

   ```bash
   xsh git/hub/run -- gh pr create --fill
   xsh git/hub/run -u alice-corp -- gh pr list   # explicit override
   ```

   Each call snapshots `~/.config/gh` to a private mode-700 tempdir,
   runs `gh auth switch -u <account>` against the **copy**, and exports
   `GH_CONFIG_DIR` only for the wrapped command. The real config is never
   mutated, so other shell sessions and credential-helper invocations are
   unaffected — even when several `git/hub/run` calls are in flight at the
   same time.

3. Wire `git/hub/ssh` into git for transparent SSH routing on bare
   `git@github.com:<org>/<repo>.git` URLs:

   ```bash
   xsh imports git/hub/ssh
   git config --global core.sshCommand git-hub-ssh
   ```

   Now `git clone git@github.com:<org>/<repo>.git` (or `gh repo clone`,
   or the web "Clone with SSH" copy-paste) auto-resolves to the right
   `~/.ssh/github-<account>` key — without rewriting the URL stored in
   the cloned `origin`. SSH key selection happens in the wrapper based on
   the org parsed from git's `git-{upload,receive}-pack` command line.

   The wrapper falls through to plain `ssh` for any host that isn't
   `git@github.com` (CodeCommit, EC2, the per-account `github-<name>`
   aliases, etc.) and for any org that isn't in
   `XSH_GIT_HUB_ACCOUNTS` — letting your existing SSH config handle
   those cases unchanged.


## Development

Run the test suite:

```bash
xsh load xsh-lib/git
bash test.sh
```

For local iteration against a working copy that hasn't been pushed yet, link
the workspace as a development library and re-run with `XSH_DEV=1`:

```bash
xsh lib-dev-manager link xsh-lib/git /path/to/parent-of-this-repo
XSH_DEV=1 bash test.sh
```

Network-dependent tests (real `gh` round-trips) are skipped by default.
Enable them with `XSH_GIT_TEST_NETWORK=1` once you have a logged-in `gh`
account available.

CI runs the same `test.sh` on `ubuntu-latest` and `macos-latest` for every
push and PR. See the
[ci-unittest workflow](.github/workflows/ci-unittest.yml).
