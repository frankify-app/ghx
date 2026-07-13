#!/usr/bin/env bats
# PR verbs on both backends.

load test_helper

setup() { common_setup; }

curl_argv() { cat "$MOCK_CURL_ARGV_FILE"; }
curl_arg_after() { awk -v f="$1" '$0==f{getline; print; exit}' "$MOCK_CURL_ARGV_FILE"; }

fj_repo() {
    make_repo "https://git.example.com/frank/widgets.git"
    make_mock_curl
    export GHX_FORGEJO_TOKEN="tkn"
}

gh_repo() {
    make_repo "https://github.com/frank/widgets.git"
    make_mock_gh
}

@test "github: pr create --closes injects closing keyword into body" {
    gh_repo
    run "$GHX" pr create --title "T" --body "Adds things." --closes 12
    [ "$status" -eq 0 ]
    grep -qF -- "--body" "$MOCK_GH_ARGV_FILE"
    tr '\n' ' ' < "$MOCK_GH_ARGV_FILE" | grep -qF "Closes #12"
    # --closes itself must not leak through to gh
    ! grep -qF -- "--closes" "$MOCK_GH_ARGV_FILE"
}

@test "forgejo: pr create --closes injects closing keyword into body" {
    fj_repo
    run "$GHX" pr create --title "T" --body "Adds things." --base main --head feat --closes 12
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/pulls"
    local payload
    payload="$(curl_arg_after --data)"
    [ "$(echo "$payload" | jq -r .title)" = "T" ]
    echo "$payload" | jq -r .body | grep -qF "Closes #12"
    [ "$(echo "$payload" | jq -r .base)" = "main" ]
    [ "$(echo "$payload" | jq -r .head)" = "feat" ]
}

@test "forgejo: pr view --comments fetches pr, comments and reviews" {
    fj_repo
    export MOCK_CURL_STDOUT='{}'
    run "$GHX" pr view 5 --comments
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/pulls/5"
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/issues/5/comments"
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/pulls/5/reviews"
}

@test "forgejo: pr list and pr comment hit pulls/issue-comment endpoints" {
    fj_repo
    export MOCK_CURL_STDOUT='[]'
    run "$GHX" pr list
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/pulls"
    run "$GHX" pr comment 5 --body "note"
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/issues/5/comments"
}

@test "forgejo: pr edit --add-reviewer posts to requested_reviewers" {
    fj_repo
    export MOCK_CURL_STDOUT='{}'
    run "$GHX" pr edit 5 --add-reviewer alice
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/pulls/5/requested_reviewers"
    [ "$(curl_arg_after --data | jq -c .reviewers)" = '["alice"]' ]
}

@test "github: pr review assembles review payload via gh api" {
    gh_repo
    run "$GHX" pr review 42 --body "two notes" \
        --code-comment "src/auth.ts:88:null check missing" \
        --code-comment "src/auth.ts:120:dead branch"
    [ "$status" -eq 0 ]
    local argv payload
    argv="$(tr '\n' ' ' < "$MOCK_GH_ARGV_FILE")"
    echo "$argv" | grep -qF "api"
    echo "$argv" | grep -qF "pulls/42/reviews"
    payload="$(awk '/^--input$|^-f$|^--raw-field$/{getline; print; exit}' "$MOCK_GH_ARGV_FILE")"
    if [ -z "$payload" ]; then
        payload="$(grep -E '^\{' "$MOCK_GH_ARGV_FILE" | head -1)"
    fi
    [ "$(echo "$payload" | jq -r .event)" = "COMMENT" ]
    [ "$(echo "$payload" | jq -r .body)" = "two notes" ]
    [ "$(echo "$payload" | jq -r '.comments | length')" = "2" ]
    [ "$(echo "$payload" | jq -r '.comments[0].path')" = "src/auth.ts" ]
    [ "$(echo "$payload" | jq -r '.comments[0].line')" = "88" ]
    [ "$(echo "$payload" | jq -r '.comments[1].body')" = "dead branch" ]
}

@test "forgejo: pr review posts reviews payload with inline comments" {
    fj_repo
    export MOCK_CURL_STDOUT='{}'
    run "$GHX" pr review 42 --body "summary" --code-comment "a.sh:3:tighten quoting"
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/pulls/42/reviews"
    local payload
    payload="$(curl_arg_after --data)"
    [ "$(echo "$payload" | jq -r .event)" = "COMMENT" ]
    [ "$(echo "$payload" | jq -r '.comments[0].path')" = "a.sh" ]
    [ "$(echo "$payload" | jq -r '.comments[0].new_position')" = "3" ]
    [ "$(echo "$payload" | jq -r '.comments[0].body')" = "tighten quoting" ]
}

@test "pr review with --body only sends no inline comments" {
    fj_repo
    export MOCK_CURL_STDOUT='{}'
    run "$GHX" pr review 42 --body "just a summary"
    [ "$status" -eq 0 ]
    [ "$(curl_arg_after --data | jq -r '.comments | length')" = "0" ]
}

@test "code-comment bodies may contain colons" {
    fj_repo
    export MOCK_CURL_STDOUT='{}'
    run "$GHX" pr review 1 --code-comment "f.sh:2:note: see RFC 1234: details"
    [ "$status" -eq 0 ]
    [ "$(curl_arg_after --data | jq -r '.comments[0].body')" = "note: see RFC 1234: details" ]
}

@test "forgejo: pr checks resolves head sha then fetches commit status" {
    fj_repo
    export MOCK_CURL_STDOUT='{"head":{"sha":"abc123"}}'
    run "$GHX" pr checks 5
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/pulls/5"
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/commits/abc123/status"
}

@test "github: pr checks and pr status forward to gh" {
    gh_repo
    run "$GHX" pr checks 5
    [ "$status" -eq 0 ]
    [ "$(tr '\n' ' ' < "$MOCK_GH_ARGV_FILE")" = "pr checks 5 " ]
    run "$GHX" pr status
    [ "$(tr '\n' ' ' < "$MOCK_GH_ARGV_FILE")" = "pr status " ]
}
