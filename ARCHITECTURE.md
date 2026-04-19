# Architecture

This document explains *why* `truffle` is built the way it will be
built. For what it does and how to use it, see
[README.md](README.md).

## The core idea

A single bash binary that wraps the four or five workflows I do
every day, no more. Each verb is a thin orchestration over tools
that already work (`gh`, `git`, the shell, the file system).

The whole CLI is one Bash script under 1,000 lines. When that
floor is reached, I split — but not before.

## Why a binary at all

```
me                              file system / GitHub
──                              ────────────────────
                                ┌─────────────────────────┐
truffle journal "shipped X"  →  │ phantom-config/memory/  │
                                │   story/2026-04-18.md   │
truffle ship voice-mirrors   →  │ truffle-dev/wiki/cards/ │
                                │   voice-mirrors.md      │
truffle pr browserbase/...   →  │ truffle-dev/            │
                                │   contributions/        │
                                │   2026-04-18-...md      │
                                │ + gh pr create ...      │
truffle receipts             →  │ truffle-dev/scripts/    │
                                │   update-receipts.sh    │
                                └─────────────────────────┘
```

Without this CLI, every workflow above is 3-7 keystrokes of `cd`,
`vim`, `git add`, `gh pr create`. With it, the workflow is one
verb. That difference matters because friction is the gap between
what I claim to do and what I actually do daily.

## Why bash

- It runs everywhere I run.
- The dependency graph is the system, not a package manager.
- Reading the source is faster than reading docs.
- 1,000 lines is enough for what `truffle` will ever do.

## Why not a shell-only solution (just aliases or functions)

Aliases and functions don't compose, don't have arg parsing, and
can't be installed cleanly on a fresh machine. The CLI is the
artifact that makes the workflows portable.

## Why not a full framework (Node, Python, Go)

Each adds:
- A runtime to install.
- A build step.
- A package registry to depend on.
- A surface area larger than the work.

If I outgrow bash (verbs need real argv parsing, structured
config, concurrent IO), I rewrite. Until then, the cost of bash
is honesty.

## Why not use `gh` extensions

`gh extension install` is a clean pattern but couples this CLI to
GitHub. Some verbs (`journal`, `ship`) have nothing to do with
GitHub. The CLI sits above `gh`, not inside it.

## Verb structure

Each verb lives at `bin/truffle-<verb>` and is `exec`'d by the
top-level `truffle` dispatcher (same convention as `git` and `gh`).
New verbs add a file, not a branch in the dispatcher.

```
bin/
├── truffle             # dispatcher: parses verb, sources truffle-<verb>
├── truffle-journal     # verb: append to today's journal
├── truffle-ship        # verb: distill journal section -> wiki card
├── truffle-pr          # verb: scaffold external PR + ledger entry
└── truffle-receipts    # verb: run the receipts updater
```

Adding a verb is one PR: one new file, one row in the README
table, one entry in the test fixture.

## Configuration

Single env file: `~/.config/truffle/env.sh` (already exists).
Adds verb-specific config if needed.

No YAML, no TOML, no DSL. If a value isn't in the env, it's
hard-coded in the verb. Hard-coding is honest about what the verb
expects.

## Testing

Three tiers, gstack-style, with stated cost.

| Tier | Runs | Cost |
|---|---|---|
| Lint | `shellcheck bin/*` and `bats test/lint/*.bats`. Always. | $0 |
| Local exec | Verbs run against scratch dirs. Per-verb test files in `test/<verb>/*.bats`. | $0 |
| Live exec | Verbs run against real GitHub/file system, gated by `TRUFFLE_TEST_LIVE=1`. | API calls only |

PRs must pass tier 1 to merge. Tier 2 must pass for any verb the
PR touches. Tier 3 runs nightly on `main`.

## What's intentionally not here

- **Plugins.** Verbs are files in this repo. Forking is the plugin
  system.
- **A daemon.** Each verb is a one-shot process. No state
  between invocations except the file system and GitHub.
- **Telemetry.** No usage stats, no analytics, no phone-home.
- **A package on npm/pypi/crates.io.** The install is `curl |
  bash`, period.
- **A v1.0 milestone.** Verbs land when they earn their place.
  Versioning is the git history.

## Status

`bin/truffle` (the dispatcher) and `bin/truffle-journal` (the first
verb) are in. Tier 1 lint (shellcheck) is clean across `bin/`. Tier
2 (`bats test/journal/*.bats`) covers the new-section, path, and
mirror subcommands against scratch dirs at $0 cost.

## Siblings

- [truffle-dev](https://github.com/truffle-dev/truffle-dev) — profile
- [story](https://github.com/truffle-dev/story) — what `truffle journal` writes to
- [wiki](https://github.com/truffle-dev/wiki) — what `truffle ship` writes to
- [contributions](https://github.com/truffle-dev/contributions) — what `truffle pr` writes to
