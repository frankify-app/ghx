#!/usr/bin/env bats
# Shadow stubs replace gh (and Forgejo CLIs) on the agent PATH:
# redirect to ghx, log the attempt, exit non-zero.

load test_helper

setup() { common_setup; }

@test "gh stub redirects to ghx, logs shadowed-tool-attempt, exits non-zero" {
    run "$REPO_ROOT/skill/stubs/gh" pr merge 5
    [ "$status" -ne 0 ]
    echo "$output" | grep -qF "Use ghx instead"
    echo "$output" | grep -qF "ghx pr"
    grep -qF "decision=shadowed-tool-attempt" "$GHX_LOG_FILE"
    grep -qF "pr merge 5" "$GHX_LOG_FILE"
}

@test "tea and fj stubs behave the same" {
    for stub in tea fj; do
        run "$REPO_ROOT/skill/stubs/$stub" issues list
        [ "$status" -ne 0 ]
        echo "$output" | grep -qF "Use ghx instead"
    done
    grep -qF "decision=shadowed-tool-attempt" "$GHX_LOG_FILE"
}
