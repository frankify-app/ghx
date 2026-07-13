# Verb table — the single source of truth for what ghx implements.
#
# GHX_USAGE maps each implemented verb to its one-line usage string.
# A verb is implemented if and only if it is a key here; the router and
# --help both read this table. Handlers are resolved by naming
# convention: <backend>_<verb with spaces/dashes as underscores>,
# e.g. "pr create" on the forgejo backend -> forgejo_pr_create.
#
# GHX_MIN_FORGEJO maps a verb to the minimum Forgejo version its REST
# endpoints require, when that minimum is above the support floor
# (docs/adr/0001). Consulted only on API failure (check-on-failure).

declare -A GHX_USAGE=(
    ["issue create"]="ghx issue create --title <t> [--body <b>] [--label <l>]... [--assignee <a>]... [--milestone <m>]"
    ["issue view"]="ghx issue view <number> [--comments]"
    ["issue list"]="ghx issue list"
    ["issue comment"]="ghx issue comment <number> --body <text>"
    ["issue edit"]="ghx issue edit <number> [--add-label|--remove-label <l>]... [--add-assignee|--remove-assignee <a>]... [--milestone <m>|--remove-milestone]"
    ["pr create"]="ghx pr create --title <t> [--body <b>] [--base <branch>] [--head <branch>] [--closes <issue-number>]"
    ["pr view"]="ghx pr view <number> [--comments]"
    ["pr list"]="ghx pr list"
    ["pr comment"]="ghx pr comment <number> --body <text>"
    ["pr edit"]="ghx pr edit <number> [--add-label|--remove-label <l>]... [--add-assignee|--remove-assignee <a>]... [--add-reviewer|--remove-reviewer <r>]... [--milestone <m>|--remove-milestone]"
    ["pr review"]="ghx pr review <number> [--body <summary>] [--code-comment <path>:<line>:<text>]..."
    ["pr checks"]="ghx pr checks <number>"
    ["pr status"]="ghx pr status"
    ["run list"]="ghx run list"
    ["run view"]="ghx run view <run-id>"
)

# DECISION:SCOPE — Actions run endpoints (repos/{o}/{r}/actions/runs[/{id}])
# are pinned to the 15.0.2 support floor but were verified against API
# docs only, not a live 15.0.2 instance; the check-on-failure gate keeps
# a shape mismatch loud instead of silent.
declare -A GHX_MIN_FORGEJO=(
    ["run list"]="15.0.2"
    ["run view"]="15.0.2"
)
