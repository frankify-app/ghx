# Backend detection and verb dispatch.

# ghx_reject_flag <verb> <flag>
# Rejects a flag/argument outside the verb's allowlist. This is the same
# boundary as an unimplemented verb: exit 3, logged, usage shown.
# Returns: never — exits 3.
ghx_reject_flag() {
    local verb=$1 flag=$2
    echo "ghx: not a ghx command: '$flag' is not part of '$verb'" >&2
    echo "usage: ${GHX_USAGE[$verb]:-}" >&2
    ghx_log not-a-ghx-command 3 - "$verb" "${GHX_ARGV[@]}"
    exit 3
}

# ghx_detect_backend
# Detects the forge backend from the git remote "origin".
# Returns (stdout): "github", or "forgejo <https-base-url>".
# Errors: exits 4 when there is no git repo, no remote, or the remote
# URL cannot be parsed — never guesses.
ghx_detect_backend() {
    local url
    if ! url="$(git remote get-url origin 2>/dev/null)"; then
        echo "ghx: host detection failed — no git remote 'origin' found (run inside a repo with a remote)" >&2
        ghx_log host-detection-failed 4 - - "${GHX_ARGV[@]}"
        exit 4
    fi
    if [[ "$url" == *github.com* ]]; then
        echo "github"
        return
    fi
    # Forgejo: derive https base URL from the remote host.
    # Handles https://host/owner/repo(.git) and git@host:owner/repo(.git).
    local host
    if [[ "$url" =~ ^[a-z+]+://([^/@]*@)?([^/:]+) ]]; then
        host="${BASH_REMATCH[2]}"
    elif [[ "$url" =~ ^([^@]+@)?([^:/]+): ]]; then
        host="${BASH_REMATCH[2]}"
    else
        echo "ghx: host detection failed — cannot parse remote URL: $url" >&2
        ghx_log host-detection-failed 4 - - "${GHX_ARGV[@]}"
        exit 4
    fi
    echo "forgejo https://$host"
}

# ghx_dispatch <verb> <args...>
# Routes an implemented verb to its backend handler.
# Params: verb — a key of GHX_USAGE; args — the remaining CLI args.
# Returns: the handler's stdout/exit code. For github, gh's exit code
# is passed through unchanged. Logs the routed decision.
ghx_dispatch() {
    local verb=$1
    shift
    local detected backend base_url
    # Command substitution runs in a subshell, so the detection function's
    # exit 4 must be re-raised here to abort the parent.
    detected="$(ghx_detect_backend)" || exit "$?"
    read -r backend base_url <<<"$detected"
    local handler="${backend}_${verb// /_}"
    local rc=0
    if [[ "$backend" == "github" ]]; then
        "$handler" "$@" || rc=$?
    else
        GHX_FORGEJO_URL="$base_url" "$handler" "$@" || rc=$?
    fi
    ghx_log routed "$rc" "$backend" "$verb" "${GHX_ARGV[@]}"
    exit "$rc"
}
