#!/usr/bin/env bash
# Host-tool checks for agentic-engineering repos.
# Default: report only. --install / --fix: bootstrap missing host CLIs (never project deps).
set -euo pipefail

INSTALL=false
if [[ "${1:-}" == "--install" || "${1:-}" == "--fix" ]]; then
    INSTALL=true
fi

# Required host tools for this generated project.
REQUIRED_TOOLS=(git npx uvx gh)
REQUIRED_TOOLS+=(prek)

pass=0
fail=0

check_tool() {
    local tool=$1
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✓ $tool"
        pass=$((pass + 1))
        return 0
    fi
    echo "✗ $tool"
    fail=$((fail + 1))
    return 1
}

warn_tool() {
    local tool=$1
    local message=$2
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✓ $tool"
        pass=$((pass + 1))
    else
        echo "⚠ $tool — $message"
    fi
}

detect_pkg_manager() {
    if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        echo brew
    elif command -v apt-get >/dev/null 2>&1; then
        echo apt
    elif command -v apt >/dev/null 2>&1; then
        echo apt
    else
        echo unknown
    fi
}

manual_install_hint() {
    local tool=$1
    case "$tool" in
        git) echo "Install git via your platform package manager." ;;
        gh) echo "brew install gh  OR  sudo apt-get install -y gh" ;;
        npx) echo "brew install node  OR  sudo apt-get install -y npm" ;;
        uvx) echo "brew install uv  OR  curl -LsSf https://astral.sh/uv/install.sh | sh" ;;
        prek) echo "brew install prek  OR  see https://github.com/j178/prek#installation" ;;
        *) echo "Install $tool manually." ;;
    esac
}

install_tool() {
    local tool=$1
    local mgr
    mgr=$(detect_pkg_manager)

    if [[ "$mgr" == unknown ]]; then
        echo "Cannot auto-install $tool: unrecognized platform or package manager."
        manual_install_hint "$tool"
        return 1
    fi

    case "$tool" in
        git)
            case "$mgr" in
                brew) brew install git ;;
                apt) sudo apt-get install -y git ;;
            esac
            ;;
        gh)
            case "$mgr" in
                brew) brew install gh ;;
                apt) sudo apt-get install -y gh ;;
            esac
            ;;
        npx)
            case "$mgr" in
                brew) brew install node ;;
                apt) sudo apt-get install -y npm ;;
            esac
            ;;
        uvx)
            case "$mgr" in
                brew) brew install uv ;;
                apt) curl -LsSf https://astral.sh/uv/install.sh | sh ;;
            esac
            ;;
        prek)
            case "$mgr" in
                brew) brew install prek ;;
                apt)
                    echo "Cannot auto-install prek via apt."
                    manual_install_hint prek
                    return 1
                    ;;
            esac
            ;;
        *)
            echo "No install recipe for $tool."
            return 1
            ;;
    esac
}

echo "agentic doctor — host tool check"
echo

missing=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! check_tool "$tool"; then
        missing+=("$tool")
    fi
done

# ghx gateway checks: ghx always; backend deps per the repo's forge host
# (github remote -> gh; anything else -> curl+jq+token for Forgejo REST).
echo
echo "ghx gateway:"
warn_tool ghx "not on PATH — agents cannot reach the forge gateway"
remote_url="$(git remote get-url origin 2>/dev/null || true)"
if [[ "$remote_url" == *github.com* ]]; then
    warn_tool gh "github remote detected but gh is missing"
elif [[ -n "$remote_url" ]]; then
    warn_tool curl "forgejo remote detected but curl is missing"
    warn_tool jq "forgejo remote detected but jq is missing"
    if [[ -n "${GHX_FORGEJO_TOKEN:-}" ]]; then
        echo "✓ GHX_FORGEJO_TOKEN"
        pass=$((pass + 1))
    else
        echo "⚠ GHX_FORGEJO_TOKEN — not set; forgejo backend calls will fail"
    fi
fi



echo
echo "Summary: $pass ok, $fail required missing"

if [[ ${#missing[@]} -eq 0 ]]; then
    exit 0
fi

if [[ "$INSTALL" != true ]]; then
    echo
    echo "Re-run with --install to bootstrap missing host tools."
    for tool in "${missing[@]}"; do
        manual_install_hint "$tool"
    done
    exit 1
fi

echo
echo "Installing missing tools..."
install_failed=false
for tool in "${missing[@]}"; do
    if ! install_tool "$tool"; then
        install_failed=true
    fi
done

if [[ "$install_failed" == true ]]; then
    exit 1
fi

echo
echo "Re-checking..."
exec "$0"

