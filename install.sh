#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/claude_profiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_LINE="source \"$INSTALL_DIR/claude-profile.sh\""
RC_COMMENT="# Claude Code Profile Manager"

info()  { echo "[info]  $*"; }
ok()    { echo "[ok]    $*"; }
warn()  { echo "[warn]  $*"; }
error() { echo "[error] $*" >&2; }

install_script() {
    mkdir -p "$INSTALL_DIR"
    cp "$SCRIPT_DIR/claude-profile.sh" "$INSTALL_DIR/claude-profile.sh"
    chmod +x "$INSTALL_DIR/claude-profile.sh"
    ok "Installed claude-profile.sh to $INSTALL_DIR/"
}

add_to_rc() {
    local rc_file="$1"
    if [ ! -f "$rc_file" ]; then
        info "Skipping $rc_file (not found)"
        return
    fi
    if grep -qF "claude-profile.sh" "$rc_file" 2>/dev/null; then
        info "$rc_file already configured, skipping"
        return
    fi
    printf '\n%s\n%s\n' "$RC_COMMENT" "$SOURCE_LINE" >> "$rc_file"
    ok "Added source line to $rc_file"
}

create_default_profile() {
    local default_dir="$INSTALL_DIR/profile_default"
    if [ -d "$default_dir" ]; then
        info "profile_default already exists, skipping"
        return
    fi

    if [ -d "$HOME/.claude" ]; then
        cp -a "$HOME/.claude" "$default_dir"
        ok "Copied existing ~/.claude to profile_default"
    else
        mkdir -p "$default_dir"
        cat > "$default_dir/settings.json" <<'SETTINGS'
{
  "permissions": {
    "allow": []
  }
}
SETTINGS
        ok "Created empty profile_default"
    fi
}

main() {
    echo "=== Claude Code Profile Manager - Install ==="
    echo ""

    install_script
    create_default_profile

    echo ""
    echo "Configuring shell RC files..."
    add_to_rc "$HOME/.bashrc"
    add_to_rc "$HOME/.zshrc"

    echo ""
    echo "=== Installation complete ==="
    echo ""
    echo "To start using now:  source $INSTALL_DIR/claude-profile.sh"
    echo "Or open a new terminal."
    echo ""
    echo "Quick start:"
    echo "  claude-profile list              # list profiles"
    echo "  claude-profile create work       # create new profile"
    echo "  claude-profile use work          # switch profile"
    echo "  claude login                     # authenticate"
}

main "$@"
