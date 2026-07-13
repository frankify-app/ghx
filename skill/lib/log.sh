# Append-only invocation log.
#
# Log path: $GHX_LOG_FILE, else ${XDG_STATE_HOME:-~/.local/state}/ghx/ghx.log.
# One line per invocation: tab-separated key=value pairs. Never logs tokens.

# ghx_log <decision> <exit_code> <backend> <verb> <argv...>
# Params:
#   decision  — routed | not-a-ghx-command | host-detection-failed |
#               version-unsupported | shadowed-tool-attempt
#   exit_code — the code the invocation is exiting with
#   backend   — github | forgejo | "-" when unresolved
#   verb      — the matched verb or "-" when unmatched
#   argv      — the raw argv of the invocation
# Returns: 0; creates the log directory on first use. Logging failures
# are not swallowed (set -e propagates them) — a broken log path is a
# real error, not a condition to hide.
ghx_log() {
    local decision=$1 exit_code=$2 backend=$3 verb=$4
    shift 4
    local log_file="${GHX_LOG_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/ghx/ghx.log}"
    mkdir -p "$(dirname "$log_file")"
    printf 'ts=%s\targv=%s\tbackend=%s\tverb=%s\tdecision=%s\texit=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" "$backend" "$verb" "$decision" "$exit_code" \
        >> "$log_file"
}
