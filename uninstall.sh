#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/claude_profiles"

info()  { echo "[info]  $*"; }
ok()    { echo "[ok]    $*"; }
warn()  { echo "[warn]  $*"; }

remove_from_rc() {
    local rc_file="$1"
    if [ ! -f "$rc_file" ]; then
        return
    fi
    if grep -qF "claude-profile.sh" "$rc_file" 2>/dev/null; then
        # Remove the comment line and source line
        sed -i '/# Claude Code Profile Manager/d' "$rc_file"
        sed -i '/claude-profile\.sh/d' "$rc_file"
        ok "Removed from $rc_file"
    else
        info "$rc_file has no claude-profile entry"
    fi
}

main() {
    echo "=== Claude Code Profile Manager - Uninstall ==="
    echo ""

    remove_from_rc "$HOME/.bashrc"
    remove_from_rc "$HOME/.zshrc"

    if [ -f "$INSTALL_DIR/claude-profile.sh" ]; then
        rm "$INSTALL_DIR/claude-profile.sh"
        ok "Removed $INSTALL_DIR/claude-profile.sh"
    fi

    # Unset env var in current shell
    unset CLAUDE_CONFIG_DIR 2>/dev/null || true
    unset -f claude-profile 2>/dev/null || true

    echo ""
    echo "=== Uninstall complete ==="
    echo ""
    echo "Profile data preserved at: $INSTALL_DIR/profile_*/"
    echo "To delete all profile data: rm -rf $INSTALL_DIR"
}

main "$@"
