#!/usr/bin/env bats
# Backend dispatch: remote host decides github (gh forward) vs forgejo (REST).

load test_helper

setup() { common_setup; }

@test "github remote forwards implemented verb to gh with identical args" {
    make_repo "https://github.com/frankify-app/ghx.git"
    make_mock_gh
    export MOCK_GH_STDOUT="issue list output"
    run "$GHX" issue list
    [ "$status" -eq 0 ]
    [ "$output" = "issue list output" ]
    [ "$(cat "$MOCK_GH_ARGV_FILE")" = "issue
list" ]
}

@test "github backend passes gh's exit code through" {
    make_repo "git@github.com:frankify-app/ghx.git"
    make_mock_gh
    export MOCK_GH_EXIT=7
    run "$GHX" issue list
    [ "$status" -eq 7 ]
}

@test "routed invocation logs backend, verb and decision" {
    make_repo "https://github.com/frankify-app/ghx.git"
    make_mock_gh
    run "$GHX" issue list
    local line
    line="$(tail -1 "$GHX_LOG_FILE")"
    echo "$line" | grep -qF "decision=routed"
    echo "$line" | grep -qF "backend=github"
    echo "$line" | grep -qF "verb=issue list"
}

@test "no git remote exits 4 with clear message" {
    make_repo
    run "$GHX" issue list
    [ "$status" -eq 4 ]
    echo "$output" | grep -qiF "remote"
}

@test "outside a git repo exits 4" {
    cd "$TEST_TMP"
    run "$GHX" issue list
    [ "$status" -eq 4 ]
}
