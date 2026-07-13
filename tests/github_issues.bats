#!/usr/bin/env bats
# GitHub backend issue verbs forward to gh with identical args.

load test_helper

setup() {
    common_setup
    make_repo "https://github.com/frank/widgets.git"
    make_mock_gh
}

@test "issue create forwards flags to gh unchanged" {
    run "$GHX" issue create --title "T" --body "B" --label bug
    [ "$status" -eq 0 ]
    [ "$(head -2 "$MOCK_GH_ARGV_FILE" | tr '\n' ' ')" = "issue create " ]
    grep -qF -- "--label" "$MOCK_GH_ARGV_FILE"
}

@test "issue view --comments forwards to gh" {
    run "$GHX" issue view 5 --comments
    [ "$status" -eq 0 ]
    [ "$(tr '\n' ' ' < "$MOCK_GH_ARGV_FILE")" = "issue view 5 --comments " ]
}

@test "issue comment forwards to gh" {
    run "$GHX" issue comment 5 --body "note"
    [ "$status" -eq 0 ]
    [ "$(tr '\n' ' ' < "$MOCK_GH_ARGV_FILE")" = "issue comment 5 --body note " ]
}
