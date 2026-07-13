#!/usr/bin/env bats
# CI-read verbs and the stateless version gate (ADR 0001):
# gated verbs attempt the call; only on failure is /version probed.

load test_helper

setup() { common_setup; }

curl_argv() { cat "$MOCK_CURL_ARGV_FILE"; }

fj_repo() {
    make_repo "https://git.example.com/frank/widgets.git"
    make_mock_curl
    export GHX_FORGEJO_TOKEN="tkn"
    export MOCK_CURL_SCRIPT="$TEST_TMP/curl_script.sh"
}

@test "github: run list and run view forward to gh" {
    make_repo "https://github.com/frank/widgets.git"
    make_mock_gh
    run "$GHX" run list
    [ "$status" -eq 0 ]
    [ "$(tr '\n' ' ' < "$MOCK_GH_ARGV_FILE")" = "run list " ]
    run "$GHX" run view 123
    [ "$(tr '\n' ' ' < "$MOCK_GH_ARGV_FILE")" = "run view 123 " ]
}

@test "forgejo: run list hits the actions runs endpoint, no version probe on success" {
    fj_repo
    cat > "$MOCK_CURL_SCRIPT" <<'EOF'
MOCK_CURL_STDOUT='{"workflow_runs":[]}'
EOF
    run "$GHX" run list
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/actions/runs"
    ! curl_argv | grep -qF "/api/v1/version"
}

@test "forgejo: run view fetches a single run" {
    fj_repo
    cat > "$MOCK_CURL_SCRIPT" <<'EOF'
MOCK_CURL_STDOUT='{"id":9}'
EOF
    run "$GHX" run view 9
    [ "$status" -eq 0 ]
    curl_argv | grep -qF "/api/v1/repos/frank/widgets/actions/runs/9"
}

@test "gated verb failing on an old instance reports version-unsupported, exit 5" {
    fj_repo
    cat > "$MOCK_CURL_SCRIPT" <<'EOF'
case "${@: -1}" in
    */version) MOCK_CURL_STDOUT='{"version":"11.0.1"}'; MOCK_CURL_HTTP_CODE=200 ;;
    *) MOCK_CURL_STDOUT='{"message":"Not Found"}'; MOCK_CURL_HTTP_CODE=404 ;;
esac
EOF
    run "$GHX" run list
    [ "$status" -eq 5 ]
    echo "$output" | grep -qF "not supported on this Forgejo version"
    echo "$output" | grep -qF "11.0.1"
    curl_argv | grep -qF "/api/v1/version"
}

@test "gated verb failing on a supported instance surfaces the raw API error" {
    fj_repo
    cat > "$MOCK_CURL_SCRIPT" <<'EOF'
case "${@: -1}" in
    */version) MOCK_CURL_STDOUT='{"version":"15.0.2"}'; MOCK_CURL_HTTP_CODE=200 ;;
    *) MOCK_CURL_STDOUT='{"message":"boom"}'; MOCK_CURL_HTTP_CODE=500 ;;
esac
EOF
    run "$GHX" run list
    [ "$status" -eq 1 ]
    echo "$output" | grep -qF "500"
    echo "$output" | grep -qF "boom"
}

@test "gated verb failure with failing version probe exits 5 loudly" {
    fj_repo
    cat > "$MOCK_CURL_SCRIPT" <<'EOF'
MOCK_CURL_STDOUT='{"message":"nope"}'
MOCK_CURL_HTTP_CODE=404
EOF
    run "$GHX" run list
    [ "$status" -eq 5 ]
    echo "$output" | grep -qiF "version"
}

@test "version-unsupported decision is logged" {
    fj_repo
    cat > "$MOCK_CURL_SCRIPT" <<'EOF'
case "${@: -1}" in
    */version) MOCK_CURL_STDOUT='{"version":"11.0.1"}'; MOCK_CURL_HTTP_CODE=200 ;;
    *) MOCK_CURL_STDOUT='{"message":"Not Found"}'; MOCK_CURL_HTTP_CODE=404 ;;
esac
EOF
    run "$GHX" run list
    grep -qF "decision=version-unsupported" "$GHX_LOG_FILE"
}
