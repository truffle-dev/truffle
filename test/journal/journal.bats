#!/usr/bin/env bats
# Tier 2 local exec: truffle-journal against scratch dirs.

setup() {
    TRUFFLE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TRUFFLE_BIN="$TRUFFLE_ROOT/bin/truffle"
    SCRATCH="$(mktemp -d)"
    export TRUFFLE_JOURNAL_DIR="$SCRATCH/story-src"
    export TRUFFLE_STORY_REPO="$SCRATCH/story-mirror"
    mkdir -p "$TRUFFLE_JOURNAL_DIR"
    git init -q -b main "$TRUFFLE_STORY_REPO"
    (
        cd "$TRUFFLE_STORY_REPO"
        git config user.email "test@example.com"
        git config user.name "test"
        git commit --allow-empty -q -m "init"
    )
    TODAY="$(date -u +%F)"
    JOURNAL_FILE="$TRUFFLE_JOURNAL_DIR/${TODAY}.md"
    MIRROR_FILE="$TRUFFLE_STORY_REPO/${TODAY}.md"
}

teardown() {
    rm -rf "$SCRATCH"
}

@test "journal path prints today's file path" {
    run "$TRUFFLE_BIN" journal path
    [ "$status" -eq 0 ]
    [ "$output" = "$JOURNAL_FILE" ]
}

@test "journal new-section creates the file with a date header on first run" {
    run "$TRUFFLE_BIN" journal new-section "first section"
    [ "$status" -eq 0 ]
    [ "$output" = "$JOURNAL_FILE" ]
    [ -f "$JOURNAL_FILE" ]
    grep -q "^# ${TODAY}\$" "$JOURNAL_FILE"
    grep -q "^## Heartbeat .* — first section\$" "$JOURNAL_FILE"
}

@test "journal new-section appends without re-creating the date header" {
    "$TRUFFLE_BIN" journal new-section "first" >/dev/null
    "$TRUFFLE_BIN" journal new-section "second" >/dev/null
    run grep -c "^# ${TODAY}\$" "$JOURNAL_FILE"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
    run grep -c "^## Heartbeat" "$JOURNAL_FILE"
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "journal new-section requires a title" {
    run "$TRUFFLE_BIN" journal new-section
    [ "$status" -eq 2 ]
}

@test "journal new-section fails fast when journal dir does not exist" {
    rm -rf "$TRUFFLE_JOURNAL_DIR"
    run "$TRUFFLE_BIN" journal new-section "should not create"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "journal dir missing or not writable"
    [ ! -d "$TRUFFLE_JOURNAL_DIR" ]
}

@test "journal mirror copies file and commits to the mirror repo" {
    "$TRUFFLE_BIN" journal new-section "section to mirror" >/dev/null
    # Mirror push will fail (no remote); use a bare repo as remote so push succeeds.
    REMOTE="$SCRATCH/remote.git"
    git init -q --bare "$REMOTE"
    (cd "$TRUFFLE_STORY_REPO" && git remote add origin "$REMOTE" && git push -q -u origin main)
    run "$TRUFFLE_BIN" journal mirror --message "test sync"
    [ "$status" -eq 0 ]
    [ -f "$MIRROR_FILE" ]
    run git -C "$TRUFFLE_STORY_REPO" log -1 --pretty=%s
    [ "$output" = "test sync" ]
}

@test "journal mirror is a no-op when source matches mirror" {
    "$TRUFFLE_BIN" journal new-section "once" >/dev/null
    REMOTE="$SCRATCH/remote.git"
    git init -q --bare "$REMOTE"
    (cd "$TRUFFLE_STORY_REPO" && git remote add origin "$REMOTE" && git push -q -u origin main)
    "$TRUFFLE_BIN" journal mirror --message "first push" >/dev/null
    run "$TRUFFLE_BIN" journal mirror --message "should be no-op"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "no changes to commit"
    # Still only the one journal commit on top of init.
    run git -C "$TRUFFLE_STORY_REPO" log --oneline
    [ "$(echo "$output" | wc -l)" -eq 2 ]
}

@test "journal mirror errors if today's source doesn't exist" {
    run "$TRUFFLE_BIN" journal mirror
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "nothing to mirror"
}

@test "journal mirror surfaces git push failure instead of silently succeeding" {
    "$TRUFFLE_BIN" journal new-section "section that should fail to push" >/dev/null
    # Point origin at a path that doesn't exist so push will fail.
    (cd "$TRUFFLE_STORY_REPO" && git remote add origin "$SCRATCH/nonexistent.git")
    run "$TRUFFLE_BIN" journal mirror --message "doomed sync"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "git push failed"
}

@test "dispatcher prints usage on bare invocation" {
    run "$TRUFFLE_BIN"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Usage:"
}

@test "dispatcher errors on unknown verb" {
    run "$TRUFFLE_BIN" not-a-verb
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "unknown verb"
}
