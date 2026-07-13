# Shared `pr review` argument parsing and payload assembly.
#
# The agent passes flat args; the structured review payload is built
# here so brittle JSON lives in tested code, not in agent prompts.

# ghx_parse_review_args <args...>
# Recognizes --body <text> and repeatable --code-comment <path>:<line>:<text>
# (text may itself contain colons — only the first two are separators).
# Populates globals:
#   REVIEW_BODY (string), REVIEW_COMMENTS (array of "path<TAB>line<TAB>text")
# Errors: exit 3 via ghx_reject_flag on unknown flags or a malformed
#   --code-comment value.
ghx_parse_review_args() {
    REVIEW_BODY=""
    REVIEW_COMMENTS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --body) REVIEW_BODY=$2; shift 2 ;;
            --code-comment)
                local spec=$2 path line text
                path="${spec%%:*}"
                line="${spec#*:}"; line="${line%%:*}"
                text="${spec#*:*:}"
                if [[ -z "$path" || ! "$line" =~ ^[0-9]+$ || "$text" == "$spec" ]]; then
                    ghx_reject_flag "pr review" "--code-comment $spec (expected <path>:<line>:<text>)"
                fi
                REVIEW_COMMENTS+=("$path"$'\t'"$line"$'\t'"$text")
                shift 2
                ;;
            *) ghx_reject_flag "pr review" "$1" ;;
        esac
    done
}

# ghx_review_payload <line-field-name>
# Builds the commenting-review JSON from the parsed globals.
# Params: line-field-name — "line" (GitHub) or "new_position" (Forgejo).
# Returns (stdout): compact JSON {event, body, comments:[...]}.
ghx_review_payload() {
    local line_field=$1
    local comments="[]" entry path line text
    for entry in "${REVIEW_COMMENTS[@]}"; do
        IFS=$'\t' read -r path line text <<<"$entry"
        comments="$(echo "$comments" | jq -c \
            --arg path "$path" --argjson line "$line" --arg body "$text" --arg f "$line_field" \
            '. + [{path: $path, ($f): $line, body: $body}]')"
    done
    jq -cn --arg body "$REVIEW_BODY" --argjson comments "$comments" \
        '{event: "COMMENT", body: $body, comments: $comments}'
}

# ghx_inject_closes <body> <issue-number>
# Returns (stdout): the PR body with "Closes #<n>" prepended, linking
# the PR to its issue on both forges' closing-keyword syntax.
ghx_inject_closes() {
    local body=$1 number=$2
    if [[ -z "$body" ]]; then
        echo "Closes #$number"
    else
        printf 'Closes #%s\n\n%s' "$number" "$body"
    fi
}
