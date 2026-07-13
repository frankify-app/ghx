# Shared body for shadow stubs (gh, tea, fj).

# ghx_stub_main <tool-name> <argv...>
# Prints the redirect + usage crib, logs the attempt with the
# shadowed-tool-attempt marker, exits 1.
# Returns: never — always exits 1.
ghx_stub_main() {
    local tool=$1
    shift
    cat >&2 <<EOF
$tool: Use ghx instead.
Implemented: ghx issue create|view|list|comment|edit; ghx pr create|view|list|comment|edit|review|checks|status; ghx run list|view
Example: ghx pr view 42 --comments   (see ghx --help)
EOF
    ghx_log shadowed-tool-attempt 1 - "$tool" "$@"
    exit 1
}
