#!/usr/bin/env bats
# ghx --help lists every implemented verb with one-line usage.

load test_helper

setup() { common_setup; }

@test "--help lists all implemented verbs and exits 0" {
    run "$GHX" --help
    [ "$status" -eq 0 ]
    for verb in \
        "issue create" "issue view" "issue list" "issue comment" "issue edit" \
        "pr create" "pr view" "pr list" "pr comment" "pr edit" "pr review" \
        "pr checks" "pr status" "run list" "run view"; do
        echo "$output" | grep -qF "$verb"
    done
}
