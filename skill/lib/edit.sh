# Shared metadata-only edit parser for `issue edit` and `pr edit`.
#
# The allowlist is structural: this parser recognizes only the flags
# below; anything else (gh's --title, --body, projects, sub-issues, ...)
# hits the default branch and is rejected as not-a-ghx-command.

# ghx_parse_edit_flags <verb> <args...>
# Params:
#   verb — "issue edit" or "pr edit"; reviewer flags are admitted only
#          for "pr edit".
# Populates globals (arrays unless noted):
#   EDIT_ADD_LABELS, EDIT_REMOVE_LABELS, EDIT_ADD_ASSIGNEES,
#   EDIT_REMOVE_ASSIGNEES, EDIT_ADD_REVIEWERS, EDIT_REMOVE_REVIEWERS,
#   EDIT_MILESTONE (string), EDIT_REMOVE_MILESTONE (true/false string)
# Returns: 0 on success.
# Errors: exits 3 via ghx_reject_flag on any flag outside the allowlist.
ghx_parse_edit_flags() {
    local verb=$1
    shift
    EDIT_ADD_LABELS=() EDIT_REMOVE_LABELS=()
    EDIT_ADD_ASSIGNEES=() EDIT_REMOVE_ASSIGNEES=()
    EDIT_ADD_REVIEWERS=() EDIT_REMOVE_REVIEWERS=()
    EDIT_MILESTONE="" EDIT_REMOVE_MILESTONE=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --add-label) EDIT_ADD_LABELS+=("$2"); shift 2 ;;
            --remove-label) EDIT_REMOVE_LABELS+=("$2"); shift 2 ;;
            --add-assignee) EDIT_ADD_ASSIGNEES+=("$2"); shift 2 ;;
            --remove-assignee) EDIT_REMOVE_ASSIGNEES+=("$2"); shift 2 ;;
            --milestone) EDIT_MILESTONE=$2; shift 2 ;;
            --remove-milestone) EDIT_REMOVE_MILESTONE=true; shift ;;
            --add-reviewer | --remove-reviewer)
                if [[ "$verb" != "pr edit" ]]; then
                    ghx_reject_flag "$verb" "$1"
                fi
                if [[ "$1" == "--add-reviewer" ]]; then
                    EDIT_ADD_REVIEWERS+=("$2")
                else
                    EDIT_REMOVE_REVIEWERS+=("$2")
                fi
                shift 2
                ;;
            *) ghx_reject_flag "$verb" "$1" ;;
        esac
    done
}
