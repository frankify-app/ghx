# GitHub backend — forwards implemented verbs to the gh CLI.
#
# Every handler receives the CLI args after the two verb words and must
# pass gh's stdout/stderr/exit code through unchanged.

# github_issue_list
# Returns: gh's output and exit code for `gh issue list`.
github_issue_list() {
    gh issue list "$@"
}

# github_issue_create / _view / _comment — plain forwards; gh's own
# parsing rejects malformed flags, and ghx adds nothing on this path.
github_issue_create() { gh issue create "$@"; }
github_issue_view() { gh issue view "$@"; }
github_issue_comment() { gh issue comment "$@"; }

# github_issue_edit <number> <allowlisted flags...>
# Validates the metadata-only allowlist (exit 3 on anything else), then
# forwards the original args to gh unchanged.
github_issue_edit() {
    local number=$1
    ghx_parse_edit_flags "issue edit" "${@:2}"
    gh issue edit "$@"
}

# github_pr_create [--title t] [--body b] [--base br] [--head br] [--closes n]
# Forwards to gh pr create; --closes <n> is ghx's own flag and is
# translated into a "Closes #n" line prepended to the body.
github_pr_create() {
    local args=() body="" closes=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --body) body=$2; shift 2 ;;
            --closes) closes=$2; shift 2 ;;
            --title | --base | --head) args+=("$1" "$2"); shift 2 ;;
            *) ghx_reject_flag "pr create" "$1" ;;
        esac
    done
    if [[ -n "$closes" ]]; then
        body="$(ghx_inject_closes "$body" "$closes")"
    fi
    gh pr create "${args[@]}" --body "$body"
}

# github_pr_view / _list / _comment / _checks / _status — plain forwards.
github_pr_view() { gh pr view "$@"; }
github_pr_list() { gh pr list "$@"; }
github_pr_comment() { gh pr comment "$@"; }
github_pr_checks() { gh pr checks "$@"; }
github_pr_status() { gh pr status "$@"; }

# github_pr_review <number> [--body s] [--code-comment path:line:text]...
# Submits a commenting review with inline comments via the reviews API
# (gh pr review has no inline-comment flags, so ghx builds the payload
# and posts it through gh api).
github_pr_review() {
    local number=$1
    ghx_parse_review_args "${@:2}"
    local repo_path
    repo_path="$(forgejo_repo_path)" # owner/repo parse works for any remote
    ghx_review_payload line | gh api -X POST "repos/$repo_path/pulls/$number/reviews" --input=-
}

# github_pr_edit <number> <allowlisted flags...>
# Same allowlist as issue edit plus reviewer-request flags.
github_pr_edit() {
    local number=$1
    ghx_parse_edit_flags "pr edit" "${@:2}"
    gh pr edit "$@"
}
