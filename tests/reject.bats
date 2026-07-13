#!/usr/bin/env bats
# Allowlist-only: anything not in the verb table is rejected and logged.

load test_helper

setup() { common_setup; }

@test "unimplemented verb exits 3 with 'not a ghx command'" {
    run "$GHX" api /repos/foo/bar
    [ "$status" -eq 3 ]
    echo "$output" | grep -qF "not a ghx command"
}

@test "unimplemented invocation appends a log line with decision and argv" {
    run "$GHX" repo delete something
    [ "$status" -eq 3 ]
    [ -f "$GHX_LOG_FILE" ]
    local line
    line="$(tail -1 "$GHX_LOG_FILE")"
    echo "$line" | grep -qF "decision=not-a-ghx-command"
    echo "$line" | grep -qF "repo delete something"
    echo "$line" | grep -qF "exit=3"
    echo "$line" | grep -qE "ts=[0-9]{4}-"
}

@test "log path defaults under XDG_STATE_HOME when GHX_LOG_FILE unset" {
    unset GHX_LOG_FILE
    export XDG_STATE_HOME="$TEST_TMP/state"
    run "$GHX" api anything
    [ "$status" -eq 3 ]
    [ -f "$XDG_STATE_HOME/ghx/ghx.log" ]
}
