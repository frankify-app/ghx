# GitHub backend — forwards implemented verbs to the gh CLI.
#
# Every handler receives the CLI args after the two verb words and must
# pass gh's stdout/stderr/exit code through unchanged.

# github_issue_list
# Returns: gh's output and exit code for `gh issue list`.
github_issue_list() {
    gh issue list "$@"
}
