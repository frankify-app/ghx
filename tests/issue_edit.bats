#!/usr/bin/env bats
# issue edit is metadata-only: exact flag allowlist, everything else rejected.

load test_helper

setup() { common_setup; }

curl_argv() { cat "$MOCK_CURL_ARGV_FILE"; }
curl_arg_after() { awk -v f="$1" '$0==f{getline; print; exit}' "$MOCK_CURL_ARGV_FILE"; }

fj_repo() {
    make_repo "https://git.example.com/frank/widgets.git"
    make_mock_curl
    export GHX_FORGEJO_TOKEN="tkn"
}

@test "github: allowed edit flags forward to gh" {
    make_repo "https://github.com/frank/widgets.git"
    make_mock_gh
    run "$GHX" issue edit 5 --add-label bug --remove-assignee alice --milestone v1
    [ "$status" -eq 0 ]
    [ "$(cat "$MOCK_GH_ARGV_FILE")" = "issue
edit
5
--add-label
bug
--remove-assignee
alice
--milestone
v1" ]
}

@test "github: --title is rejected with exit 3, gh never invoked" {
    make_repo "https://github.com/frank/widgets.git"
    make_mock_gh
    run "$GHX" issue edit 5 --title "new title"
    [ "$status" -eq 3 ]
    [ ! -f "$MOCK_GH_ARGV_FILE" ]
}

@test "every excluded edit flag is rejected on both verbs" {
    make_repo "https://github.com/frank/widgets.git"
    make_mock_gh
    for flag in --title --body --body-file --add-project --add-sub-issue --add-blocking --parent --type; do
        run "$GHX" issue edit 5 "$flag" x
        [ "$status" -eq 3 ]
        run "$GHX" pr edit 5 "$flag" x
        [ "$status" -eq 3 ]
    done
}

@test "forgejo: --add-label posts to the labels endpoint" {
    fj_repo
    export MOCK_CURL_STDOUT='[{"id":11,"name":"bug"}]'
    run "$GHX" issue edit 5 --add-label bug
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/issues/5/labels"
    curl_argv | grep -qF "POST"
}

@test "forgejo: --remove-label deletes from the labels endpoint" {
    fj_repo
    export MOCK_CURL_STDOUT='[{"id":11,"name":"bug"}]'
    run "$GHX" issue edit 5 --remove-label bug
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/issues/5/labels/11"
    curl_argv | grep -qF "DELETE"
}

@test "forgejo: assignee changes PATCH only the assignees field" {
    fj_repo
    export MOCK_CURL_STDOUT='{"assignees":[{"login":"bob"}]}'
    run "$GHX" issue edit 5 --add-assignee alice
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "PATCH"
    local payload
    payload="$(curl_arg_after --data)"
    [ "$(echo "$payload" | jq -c 'keys')" = '["assignees"]' ]
    echo "$payload" | jq -e '.assignees | index("alice")' >/dev/null
    echo "$payload" | jq -e '.assignees | index("bob")' >/dev/null
}

@test "forgejo: --remove-milestone PATCHes milestone null-out" {
    fj_repo
    run "$GHX" issue edit 5 --remove-milestone
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "PATCH"
    [ "$(curl_arg_after --data | jq -c .)" = '{"milestone":0}' ]
}
