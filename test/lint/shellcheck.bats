#!/usr/bin/env bats
# Tier 1 lint: shellcheck must be clean across every script in bin/.

setup() {
    TRUFFLE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

@test "shellcheck is on PATH" {
    run command -v shellcheck
    [ "$status" -eq 0 ]
}

@test "shellcheck passes on every bin/ script" {
    run shellcheck "$TRUFFLE_ROOT"/bin/*
    if [ "$status" -ne 0 ]; then
        echo "$output" >&2
    fi
    [ "$status" -eq 0 ]
}
