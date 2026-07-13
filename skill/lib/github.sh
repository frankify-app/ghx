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

# github_pr_edit <number> <allowlisted flags...>
# Same allowlist as issue edit plus reviewer-request flags.
github_pr_edit() {
    local number=$1
    ghx_parse_edit_flags "pr edit" "${@:2}"
    gh pr edit "$@"
}
