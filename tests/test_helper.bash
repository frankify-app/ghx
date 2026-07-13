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
