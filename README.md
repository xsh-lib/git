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

This project is still at version `0.x` and should be considered immature.


## Dependency

1. [xsh-lib/core](https://github.com/xsh-lib/core) — should be loaded before
   this library.

   ```bash
   xsh load xsh-lib/core
   ```

2. Some utilities have additional dependencies (e.g. `gh`, `w3m`,
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
| `git/hub/account-for-email`   | function | Look up a `gh` account name for an email via `XSH_GIT_HUB_ACCOUNT_MAP`.                                          |
| `git/hub/account-for-repo`    | function | Derive the `gh` account for the current repo from `git config user.email`, using the same mapping.               |
| `git/hub/run`                 | function | Run a command with a chosen `gh` account active, isolated from concurrent shell sessions via per-call `GH_CONFIG_DIR`. |
| `git/hub/collaborator`        | function | Add, remove, or list collaborators of the current GitHub repo. Requires `collaborator` and `w3m`.                |
| `git/rebase-i-in-dumb-term`   | script   | Helper for running `git rebase -i` in dumb terminals.                                                             |


### Multi-`gh`-account workflow

If you operate multiple GitHub accounts simultaneously (e.g. personal +
work) and rely on `~/.gitconfig`'s `includeIf "gitdir:..."` rules to switch
identities per directory tree, the `git/hub/*` utilities make it transparent
to push/PR/etc. against the right account without ever mutating the global
active account in `~/.config/gh`.

1. Map your emails to `gh` account names via an env var:

   ```bash
   export XSH_GIT_HUB_ACCOUNT_MAP="alice@personal.com=alice alice@corp.io=alice-corp"
   ```

2. Use `git/hub/run` as a transparent wrapper around any `git` or `gh`
   command. The account is auto-derived from the current repo's
   `user.email`:

   ```bash
   xsh git/hub/run -- git push origin main
   xsh git/hub/run -- gh pr create --fill
   xsh git/hub/run -u alice-corp -- gh pr list   # explicit override
   ```

   Each call snapshots `~/.config/gh` to a private mode-700 tempdir,
   `gh auth switch -u <account>` runs against the **copy**, and
   `GH_CONFIG_DIR` is exported only for the wrapped command. The real
   config is never mutated, so other shell sessions and credential-helper
   invocations are unaffected — even when several `git/hub/run` calls are
   in flight at the same time.


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
