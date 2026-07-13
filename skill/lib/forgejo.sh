# Forgejo backend — builds REST requests internally (curl + jq).
#
# Uses: GHX_FORGEJO_URL (set by dispatch from the git remote) and
# GHX_FORGEJO_TOKEN (scoped access token, never logged).

# forgejo_repo_path
# Returns (stdout): "owner/repo" parsed from the origin remote URL.
# Errors: exits 4 when the path cannot be parsed.
forgejo_repo_path() {
    local url path
    url="$(git remote get-url origin)"
    path="${url#*://*/}"          # https://host/owner/repo(.git)
    if [[ "$path" == "$url" ]]; then
        path="${url#*:}"          # git@host:owner/repo(.git)
    fi
    path="${path%.git}"
    if [[ ! "$path" == */* ]]; then
        echo "ghx: host detection failed — cannot parse owner/repo from remote URL: $url" >&2
        exit 4
    fi
    echo "$path"
}

# forgejo_api <method> <path-under-/api/v1> [json-body]
# Performs one Forgejo REST call and prints the response body.
# Params:
#   method — GET | POST | PATCH | DELETE
#   path   — e.g. repos/frank/widgets/issues/5
#   body   — optional JSON string sent as the request body
# Returns: response body on stdout, exit 0 on HTTP 2xx.
# Errors: missing token -> exit 1 with message naming GHX_FORGEJO_TOKEN;
#   HTTP >= 400 -> exit 1 with status + API message. Logs endpoint,
#   method and outcome; never the token.
forgejo_api() {
    local method=$1 path=$2 body="${3:-}"
    if [[ -z "${GHX_FORGEJO_TOKEN:-}" ]]; then
        echo "ghx: GHX_FORGEJO_TOKEN is not set — required for forgejo backend calls to ${GHX_FORGEJO_URL}" >&2
        exit 1
    fi
    local url="${GHX_FORGEJO_URL}/api/v1/${path}"
    local args=(-sS -X "$method" -H "Authorization: token ${GHX_FORGEJO_TOKEN}" -H "Content-Type: application/json")
    if [[ -n "$body" ]]; then
        args+=(--data "$body")
    fi
    # Response protocol: body lines, then the HTTP status code as the
    # final line (curl -w).
    local response http_code
    response="$(curl "${args[@]}" -w '\n%{http_code}\n' "$url")"
    http_code="$(echo "$response" | sed -n '$p' | tr -d '[:space:]')"
    response="$(echo "$response" | sed '$d')"
    ghx_log "api:${method}:${path}:http=${http_code}" 0 forgejo - "${GHX_ARGV[@]}"
    if [[ "$http_code" -ge 400 ]]; then
        local message
        message="$(echo "$response" | jq -r '.message // empty' 2>/dev/null || true)"
        echo "ghx: forgejo API error ${http_code} on ${method} ${path}: ${message:-$response}" >&2
        exit 1
    fi
    echo "$response"
}

# forgejo_issue_create --title <t> [--body <b>] [--label <l>]...
#   [--assignee <a>]... [--milestone <m>]
# Creates an issue via POST repos/{o}/{r}/issues with a jq-built body.
# Returns: API response JSON on stdout.
# Errors: unknown flag -> exit 3 (not a ghx command); API errors per
#   forgejo_api.
forgejo_issue_create() {
    local title="" body="" labels=() assignees=() milestone=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title) title=$2; shift 2 ;;
            --body) body=$2; shift 2 ;;
            --label) labels+=("$2"); shift 2 ;;
            --assignee) assignees+=("$2"); shift 2 ;;
            --milestone) milestone=$2; shift 2 ;;
            *) ghx_reject_flag "issue create" "$1" ;;
        esac
    done
    local payload
    payload="$(jq -cn --arg title "$title" --arg body "$body" \
        '{title: $title} + (if $body != "" then {body: $body} else {} end)')"
    if [[ ${#labels[@]} -gt 0 ]]; then
        payload="$(echo "$payload" | jq -c --argjson ids "$(forgejo_label_ids "${labels[@]}")" '. + {labels: $ids}')"
    fi
    if [[ ${#assignees[@]} -gt 0 ]]; then
        payload="$(echo "$payload" | jq -c --args '. + {assignees: $ARGS.positional}' "${assignees[@]}")"
    fi
    if [[ -n "$milestone" ]]; then
        payload="$(echo "$payload" | jq -c --argjson id "$(forgejo_milestone_id "$milestone")" '. + {milestone: $id}')"
    fi
    forgejo_api POST "repos/$(forgejo_repo_path)/issues" "$payload"
}

# forgejo_label_ids <name>...
# Resolves label names to their numeric IDs via GET repos/{o}/{r}/labels.
# Returns (stdout): JSON array of IDs.
# Errors: exit 1 naming the label when a name does not exist on the repo.
forgejo_label_ids() {
    local all ids
    all="$(forgejo_api GET "repos/$(forgejo_repo_path)/labels")"
    ids="[]"
    local name id
    for name in "$@"; do
        id="$(echo "$all" | jq -r --arg n "$name" '.[] | select(.name == $n) | .id')"
        if [[ -z "$id" ]]; then
            echo "ghx: label not found on repo: name=$name" >&2
            exit 1
        fi
        ids="$(echo "$ids" | jq -c --argjson id "$id" '. + [$id]')"
    done
    echo "$ids"
}

# forgejo_milestone_id <title>
# Resolves a milestone title to its ID via GET repos/{o}/{r}/milestones.
# Returns (stdout): the numeric ID.
# Errors: exit 1 naming the milestone when it does not exist.
forgejo_milestone_id() {
    local title=$1 id
    id="$(forgejo_api GET "repos/$(forgejo_repo_path)/milestones" \
        | jq -r --arg t "$title" '.[] | select(.title == $t) | .id')"
    if [[ -z "$id" ]]; then
        echo "ghx: milestone not found on repo: title=$title" >&2
        exit 1
    fi
    echo "$id"
}

# forgejo_issue_view <number> [--comments]
# Returns: the issue JSON; with --comments, the comments JSON follows.
forgejo_issue_view() {
    local number=$1
    shift
    forgejo_api GET "repos/$(forgejo_repo_path)/issues/$number"
    if [[ "${1:-}" == "--comments" ]]; then
        forgejo_api GET "repos/$(forgejo_repo_path)/issues/$number/comments"
    elif [[ $# -gt 0 ]]; then
        ghx_reject_flag "issue view" "$1"
    fi
}

# forgejo_issue_list
# Returns: open issues JSON (type=issues excludes PRs).
forgejo_issue_list() {
    if [[ $# -gt 0 ]]; then
        ghx_reject_flag "issue list" "$1"
    fi
    forgejo_api GET "repos/$(forgejo_repo_path)/issues?type=issues"
}

# forgejo_issue_edit <number> <allowlisted flags...>
# Metadata-only edit. Labels via the label endpoints; assignees and
# milestone via PATCH on the issue with only those fields.
# Returns: 0; individual API responses are suppressed except errors.
# Errors: exit 3 on non-allowlisted flags; API errors per forgejo_api.
forgejo_issue_edit() {
    local number=$1
    ghx_parse_edit_flags "issue edit" "${@:2}"
    forgejo_apply_edit "$number" "issues/$number"
}

# forgejo_apply_edit <number> <patch-path-under-repo>
# Applies parsed EDIT_* globals against the repo's REST endpoints.
# patch-path is "issues/{n}" for both issues and PRs (Forgejo PATCHes
# PR metadata through the issue endpoint for labels/assignees/milestone).
forgejo_apply_edit() {
    local number=$1 patch_path=$2 repo_path
    repo_path="$(forgejo_repo_path)"
    if [[ ${#EDIT_ADD_LABELS[@]} -gt 0 ]]; then
        forgejo_api POST "repos/$repo_path/issues/$number/labels" \
            "$(jq -cn --argjson ids "$(forgejo_label_ids "${EDIT_ADD_LABELS[@]}")" '{labels: $ids}')" >/dev/null
    fi
    local name id
    for name in "${EDIT_REMOVE_LABELS[@]}"; do
        id="$(forgejo_label_ids "$name" | jq -r '.[0]')"
        forgejo_api DELETE "repos/$repo_path/issues/$number/labels/$id" >/dev/null
    done
    if [[ ${#EDIT_ADD_ASSIGNEES[@]} -gt 0 || ${#EDIT_REMOVE_ASSIGNEES[@]} -gt 0 ]]; then
        # PATCH replaces the assignee list, so merge with the current one.
        local current merged
        current="$(forgejo_api GET "repos/$repo_path/issues/$number" | jq -c '[.assignees // [] | .[].login]')"
        merged="$(jq -cn --argjson cur "$current" \
            --args '$cur + $ARGS.positional | unique' "${EDIT_ADD_ASSIGNEES[@]}")"
        if [[ ${#EDIT_REMOVE_ASSIGNEES[@]} -gt 0 ]]; then
            merged="$(echo "$merged" | jq -c --args '. - $ARGS.positional' "${EDIT_REMOVE_ASSIGNEES[@]}")"
        fi
        forgejo_api PATCH "repos/$repo_path/$patch_path" \
            "$(jq -cn --argjson a "$merged" '{assignees: $a}')" >/dev/null
    fi
    if [[ "$EDIT_REMOVE_MILESTONE" == "true" ]]; then
        # Milestone 0 clears the field on Forgejo.
        forgejo_api PATCH "repos/$repo_path/$patch_path" '{"milestone":0}' >/dev/null
    elif [[ -n "$EDIT_MILESTONE" ]]; then
        forgejo_api PATCH "repos/$repo_path/$patch_path" \
            "$(jq -cn --argjson id "$(forgejo_milestone_id "$EDIT_MILESTONE")" '{milestone: $id}')" >/dev/null
    fi
}

# forgejo_issue_comment <number> --body <text>
# Adds a comment. Returns: created comment JSON.
# Errors: missing --body -> exit 3.
forgejo_issue_comment() {
    local number=$1 body=""
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --body) body=$2; shift 2 ;;
            *) ghx_reject_flag "issue comment" "$1" ;;
        esac
    done
    if [[ -z "$body" ]]; then
        ghx_reject_flag "issue comment" "(missing --body)"
    fi
    forgejo_api POST "repos/$(forgejo_repo_path)/issues/$number/comments" \
        "$(jq -cn --arg body "$body" '{body: $body}')"
}
