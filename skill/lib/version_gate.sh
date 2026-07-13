# Stateless Forgejo version gate (docs/adr/0001).
#
# Gated verbs attempt their real API call with no pre-flight check; only
# on failure is GET /api/v1/version probed to attribute the error.

# forgejo_gated_api <verb> <method> <path>
# Params: verb — the ghx verb (key of GHX_MIN_FORGEJO); rest as forgejo_api.
# Returns: the API response on success (exit 0).
# Errors:
#   instance version < verb minimum  -> exit 5, "not supported on this
#     Forgejo version (<found> < <required>)", logged version-unsupported
#   version probe itself fails       -> exit 5, loud (never guesses)
#   instance supported               -> the original API error, exit 1
forgejo_gated_api() {
    local verb=$1 method=$2 path=$3
    local out rc=0
    out="$(forgejo_api "$method" "$path")" || rc=$?
    if [[ $rc -eq 0 ]]; then
        echo "$out"
        return 0
    fi
    local required="${GHX_MIN_FORGEJO[$verb]:-}"
    local found probe_rc=0
    found="$(forgejo_api GET version 2>/dev/null | jq -r '.version // empty')" || probe_rc=$?
    if [[ $probe_rc -ne 0 || -z "$found" ]]; then
        echo "ghx: '$verb' failed and the Forgejo version probe (GET /api/v1/version) also failed — cannot attribute the error; check ${GHX_FORGEJO_URL}" >&2
        ghx_log version-unsupported 5 forgejo "$verb" "${GHX_ARGV[@]}"
        exit 5
    fi
    if [[ -n "$required" && "$(printf '%s\n%s\n' "$found" "$required" | sort -V | head -1)" != "$required" ]]; then
        echo "ghx: '$verb' not supported on this Forgejo version ($found < $required)" >&2
        ghx_log version-unsupported 5 forgejo "$verb" "${GHX_ARGV[@]}"
        exit 5
    fi
    # Instance is new enough — the failure is a real API error; it was
    # already printed to stderr by forgejo_api.
    exit "$rc"
}

# forgejo_run_list
# Lists Actions workflow runs. Gated: Actions endpoints stabilized late.
forgejo_run_list() {
    if [[ $# -gt 0 ]]; then
        ghx_reject_flag "run list" "$1"
    fi
    forgejo_gated_api "run list" GET "repos/$(forgejo_repo_path)/actions/runs"
}

# forgejo_run_view <run-id>
# Shows one Actions workflow run. Gated like run list.
forgejo_run_view() {
    local run_id=$1
    forgejo_gated_api "run view" GET "repos/$(forgejo_repo_path)/actions/runs/$run_id"
}
