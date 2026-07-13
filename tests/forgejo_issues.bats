#!/usr/bin/env bats
# Forgejo backend issue verbs: REST requests built internally, API mocked.

load test_helper

setup() {
    common_setup
    make_repo "https://git.example.com/frank/widgets.git"
    make_mock_curl
    export GHX_FORGEJO_TOKEN="sekrit-token-123"
}

# All curl argv lines across calls, flattened.
curl_argv() { cat "$MOCK_CURL_ARGV_FILE"; }

# The value following a flag (e.g. -d, -X) in the recorded argv.
curl_arg_after() { awk -v f="$1" '$0==f{getline; print; exit}' "$MOCK_CURL_ARGV_FILE"; }

@test "issue create posts jq-built payload to /repos/{o}/{r}/issues" {
    run "$GHX" issue create --title "Bug: crash" --body "It crashes"
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "https://git.example.com/api/v1/repos/frank/widgets/issues"
    [ "$(curl_arg_after -X)" = "POST" ]
    local payload
    payload="$(curl_arg_after --data)"
    [ "$(echo "$payload" | jq -r .title)" = "Bug: crash" ]
    [ "$(echo "$payload" | jq -r .body)" = "It crashes" ]
}

@test "issue create sends token auth header" {
    run "$GHX" issue create --title "t"
    curl_argv | grep -qF "Authorization: token sekrit-token-123"
}

@test "issue view fetches the issue" {
    export MOCK_CURL_STDOUT='{"number":5,"title":"T","body":"B"}'
    run "$GHX" issue view 5
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/issues/5"
}

@test "issue view --comments also fetches comments" {
    run "$GHX" issue view 5 --comments
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/issues/5"
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/issues/5/comments"
}

@test "issue list queries type=issues" {
    export MOCK_CURL_STDOUT='[]'
    run "$GHX" issue list
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/issues?type=issues"
}

@test "issue comment posts body to comments endpoint" {
    run "$GHX" issue comment 7 --body "follow-up note"
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/issues/7/comments"
    [ "$(curl_arg_after --data | jq -r .body)" = "follow-up note" ]
}

@test "API error surfaces status and message, exits non-zero" {
    export MOCK_CURL_HTTP_CODE=422
    export MOCK_CURL_STDOUT='{"message":"Validation Failed"}'
    run "$GHX" issue comment 7 --body "x"
    [ "$status" -ne 0 ]
    echo "$output" | grep -qF "422"
    echo "$output" | grep -qF "Validation Failed"
}

@test "log lines never contain the token" {
    run "$GHX" issue create --title "t"
    run grep -F "sekrit-token-123" "$GHX_LOG_FILE"
    [ "$status" -ne 0 ]
}

@test "missing GHX_FORGEJO_TOKEN fails with clear message" {
    unset GHX_FORGEJO_TOKEN
    run "$GHX" issue list
    [ "$status" -ne 0 ]
    echo "$output" | grep -qF "GHX_FORGEJO_TOKEN"
}
