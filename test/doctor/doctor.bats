#!/usr/bin/env bats
# Tier 2 local exec: truffle-doctor against scratch dirs.

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
        git remote add origin "$SCRATCH/remote.git"
    )
    git init -q --bare "$SCRATCH/remote.git"
}

teardown() {
    rm -rf "$SCRATCH"
}

@test "doctor passes when journal dir, mirror repo, and remote are healthy" {
    run "$TRUFFLE_BIN" doctor
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PASS  journal directory exists & writable"
    echo "$output" | grep -q "PASS  mirror repo is a git checkout"
    echo "$output" | grep -q "PASS  mirror repo has a remote configured"
    echo "$output" | grep -q "PASS  UTC date available"
    echo "$output" | grep -q "4 passed, 0 failed"
}

@test "doctor --quiet emits no stdout when healthy" {
    run "$TRUFFLE_BIN" doctor --quiet
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "doctor fails when journal dir is missing" {
    rm -rf "$TRUFFLE_JOURNAL_DIR"
    run "$TRUFFLE_BIN" doctor
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "FAIL  journal directory exists & writable"
}

@test "doctor fails when mirror repo is not a git checkout" {
    rm -rf "$TRUFFLE_STORY_REPO/.git"
    run "$TRUFFLE_BIN" doctor
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "FAIL  mirror repo is a git checkout"
}

@test "doctor fails when mirror repo has no remote" {
    git -C "$TRUFFLE_STORY_REPO" remote remove origin
    run "$TRUFFLE_BIN" doctor
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "FAIL  mirror repo has a remote configured"
}

@test "doctor --quiet still prints failures to stderr" {
    rm -rf "$TRUFFLE_JOURNAL_DIR"
    run "$TRUFFLE_BIN" doctor --quiet
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "FAIL  journal directory exists & writable"
}

@test "doctor errors on unknown arg" {
    run "$TRUFFLE_BIN" doctor --bogus
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "unknown arg"
}
