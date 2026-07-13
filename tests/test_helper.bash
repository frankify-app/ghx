# Shared BATS setup for ghx tests.
#
# Provides:
#   GHX        — absolute path to the ghx entry point under test
#   TEST_TMP   — per-test scratch dir (repo fixtures, logs, mock outputs)
#   GHX_LOG_FILE — per-test log path, exported so assertions can read it
#
# Errors: setup fails the test if the repo layout is missing.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
GHX="$REPO_ROOT/skill/bin/ghx"

common_setup() {
    TEST_TMP="$(mktemp -d "$BATS_TEST_TMPDIR/ghx-XXXXXX")"
    export GHX_LOG_FILE="$TEST_TMP/ghx.log"
    export HOME="$TEST_TMP/home"
    mkdir -p "$HOME"
}

# Install a mock `gh` on PATH that records its argv (one arg per line)
# to $TEST_TMP/gh.argv, prints $MOCK_GH_STDOUT, exits $MOCK_GH_EXIT (default 0).
make_mock_gh() {
    mkdir -p "$TEST_TMP/bin"
    cat > "$TEST_TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${MOCK_GH_ARGV_FILE}"
echo "${MOCK_GH_STDOUT:-}"
exit "${MOCK_GH_EXIT:-0}"
EOF
    chmod +x "$TEST_TMP/bin/gh"
    export MOCK_GH_ARGV_FILE="$TEST_TMP/gh.argv"
    export PATH="$TEST_TMP/bin:$PATH"
}

# Install a mock `curl` on PATH that records the full argv (one arg per
# line) to $TEST_TMP/curl.argv (appending, so multi-call verbs record all
# calls), prints $MOCK_CURL_STDOUT, and writes "$MOCK_CURL_HTTP_CODE"
# (default 200) where ghx asks for the status code.
make_mock_curl() {
    mkdir -p "$TEST_TMP/bin"
    cat > "$TEST_TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "${MOCK_CURL_ARGV_FILE}"
printf '%s\n---CALL---\n' "" >> "${MOCK_CURL_ARGV_FILE}"
echo "${MOCK_CURL_STDOUT:-{\}}"
echo "${MOCK_CURL_HTTP_CODE:-200}"
EOF
    chmod +x "$TEST_TMP/bin/curl"
    export MOCK_CURL_ARGV_FILE="$TEST_TMP/curl.argv"
    export PATH="$TEST_TMP/bin:$PATH"
}

# Create a git repo fixture with the given remote URL (or none if omitted)
# and cd into it. Returns: prints nothing; cwd is the new repo.
make_repo() {
    local remote_url="${1:-}"
    local dir="$TEST_TMP/repo"
    mkdir -p "$dir"
    cd "$dir"
    git init -q
    if [[ -n "$remote_url" ]]; then
        git remote add origin "$remote_url"
    fi
}
