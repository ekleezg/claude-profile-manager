#!/usr/bin/env bash
#
# Claude Code Profile Manager
#
# Uses CLAUDE_CONFIG_DIR to switch between isolated profiles.
# Each profile is a complete config directory (settings, credentials, history, etc.)
#
# Usage:
#   source ~/claude_profiles/claude-profile.sh
#
# Commands:
#   claude-profile list          - List available profiles
#   claude-profile current       - Show current active profile and CLAUDE_CONFIG_DIR
#   claude-profile use <name>    - Switch to a profile (sets CLAUDE_CONFIG_DIR)
#   claude-profile create <name> - Create a new empty profile (no credentials)
#   claude-profile edit <name>   - Edit a profile's settings.json
#   claude-profile diff <a> <b>  - Diff two profiles' settings

CLAUDE_PROFILES_DIR="$HOME/claude_profiles"

_claude_profile_resolve_name() {
    local name="$1"
    [[ "$name" != profile_* ]] && name="profile_$name"
    echo "$name"
}

_claude_profile_current_name() {
    if [ -n "$CLAUDE_CONFIG_DIR" ]; then
        local base
        base=$(basename "$CLAUDE_CONFIG_DIR")
        if [[ "$base" == profile_* ]]; then
            echo "$base"
            return
        fi
    fi
    echo "(default: ~/.claude)"
}

_claude_profile_list() {
    echo "Available profiles:"
    local current
    current=$(_claude_profile_current_name)
    for dir in "$CLAUDE_PROFILES_DIR"/profile_*/; do
        [ -d "$dir" ] || continue
        local name
        name=$(basename "$dir")
        local has_creds=" "
        [ -f "$dir/.credentials.json" ] && has_creds="+"
        if [ "$name" = "$current" ]; then
            echo "  * [$has_creds] $name  (active)"
        else
            echo "    [$has_creds] $name"
        fi
    done
    echo ""
    echo "  [+] = has credentials, [ ] = no credentials (needs 'claude login')"
}

_claude_profile_current() {
    local current
    current=$(_claude_profile_current_name)
    echo "Current profile: $current"
    echo "CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-(not set, using ~/.claude)}"
    echo ""

    local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    if [ -f "$config_dir/settings.json" ]; then
        echo "Settings:"
        cat "$config_dir/settings.json"
    else
        echo "Settings: (no settings.json found)"
    fi
    echo ""
    if [ -f "$config_dir/.credentials.json" ]; then
        echo "Credentials: present"
    else
        echo "Credentials: none (run 'claude login')"
    fi
}

_claude_profile_use() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Usage: claude-profile use <profile_name>"
        return 1
    fi

    name=$(_claude_profile_resolve_name "$name")

    local profile_dir="$CLAUDE_PROFILES_DIR/$name"
    if [ ! -d "$profile_dir" ]; then
        echo "Error: Profile '$name' not found at $profile_dir"
        _claude_profile_list
        return 1
    fi

    export CLAUDE_CONFIG_DIR="$profile_dir"

    echo "Switched to profile: $name"
    echo "CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR"

    if [ ! -f "$profile_dir/.credentials.json" ]; then
        echo ""
        echo "No credentials for this profile. Run 'claude login' to authenticate."
    fi
}

_claude_profile_create() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Usage: claude-profile create <profile_name>"
        return 1
    fi

    name=$(_claude_profile_resolve_name "$name")

    local profile_dir="$CLAUDE_PROFILES_DIR/$name"
    if [ -d "$profile_dir" ]; then
        echo "Error: Profile '$name' already exists."
        return 1
    fi

    mkdir -p "$profile_dir"

    # Create minimal default settings (no credentials)
    cat > "$profile_dir/settings.json" <<'SETTINGS'
{
  "permissions": {
    "allow": []
  }
}
SETTINGS

    echo "Created profile: $name"
    echo "  Directory: $profile_dir"
    echo "  Credentials: none (will prompt login on first use)"
    echo ""
    echo "Next steps:"
    echo "  claude-profile edit ${name#profile_}    # customize settings"
    echo "  claude-profile use ${name#profile_}     # switch (sets CLAUDE_CONFIG_DIR)"
    echo "  claude login                            # authenticate in new profile"
}

_claude_profile_edit() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Usage: claude-profile edit <profile_name>"
        return 1
    fi

    name=$(_claude_profile_resolve_name "$name")

    local settings_file="$CLAUDE_PROFILES_DIR/$name/settings.json"
    if [ ! -f "$settings_file" ]; then
        echo "Error: Profile '$name' not found."
        return 1
    fi

    ${EDITOR:-vi} "$settings_file"
}

_claude_profile_diff() {
    local a="$1" b="$2"
    if [ -z "$a" ] || [ -z "$b" ]; then
        echo "Usage: claude-profile diff <profile_a> <profile_b>"
        return 1
    fi

    a=$(_claude_profile_resolve_name "$a")
    b=$(_claude_profile_resolve_name "$b")

    diff --color=auto \
        "$CLAUDE_PROFILES_DIR/$a/settings.json" \
        "$CLAUDE_PROFILES_DIR/$b/settings.json"
}

claude-profile() {
    local cmd="${1:-help}"
    shift 2>/dev/null

    case "$cmd" in
        list|ls)     _claude_profile_list ;;
        current)     _claude_profile_current ;;
        use|switch)  _claude_profile_use "$@" ;;
        create|new)  _claude_profile_create "$@" ;;
        edit)        _claude_profile_edit "$@" ;;
        diff)        _claude_profile_diff "$@" ;;
        help|*)
            echo "Claude Code Profile Manager (using CLAUDE_CONFIG_DIR)"
            echo ""
            echo "Usage: claude-profile <command> [args]"
            echo ""
            echo "Commands:"
            echo "  list              List available profiles"
            echo "  current           Show active profile and CLAUDE_CONFIG_DIR"
            echo "  use <name>        Switch to a profile (exports CLAUDE_CONFIG_DIR)"
            echo "  create <name>     Create a new empty profile (no credentials)"
            echo "  edit <name>       Edit a profile's settings.json"
            echo "  diff <a> <b>      Diff two profiles' settings"
            echo ""
            echo "Profile names can omit the 'profile_' prefix."
            echo "Example: claude-profile use work"
            ;;
    esac
}

# Tab completion (bash)
if [ -n "$BASH_VERSION" ]; then
    _claude_profile_completions() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local prev="${COMP_WORDS[COMP_CWORD-1]}"

        case "$prev" in
            claude-profile)
                COMPREPLY=($(compgen -W "list current use create edit diff help" -- "$cur"))
                ;;
            use|switch|edit)
                local profiles
                profiles=$(ls -d "$CLAUDE_PROFILES_DIR"/profile_*/ 2>/dev/null | xargs -I{} basename {} | sed 's/^profile_//')
                COMPREPLY=($(compgen -W "$profiles" -- "$cur"))
                ;;
            diff)
                local profiles
                profiles=$(ls -d "$CLAUDE_PROFILES_DIR"/profile_*/ 2>/dev/null | xargs -I{} basename {} | sed 's/^profile_//')
                COMPREPLY=($(compgen -W "$profiles" -- "$cur"))
                ;;
        esac
    }
    complete -F _claude_profile_completions claude-profile
fi

# Tab completion (zsh)
if [ -n "$ZSH_VERSION" ]; then
    _claude_profile_zsh() {
        local -a subcmds profiles
        subcmds=('list:List available profiles' 'current:Show active profile' 'use:Switch to a profile' 'create:Create a new empty profile' 'edit:Edit settings.json' 'diff:Diff two profiles' 'help:Show help')

        if (( CURRENT == 2 )); then
            _describe 'command' subcmds
        elif (( CURRENT >= 3 )); then
            case "${words[2]}" in
                use|switch|edit|diff)
                    profiles=($(ls -d "$CLAUDE_PROFILES_DIR"/profile_*/ 2>/dev/null | xargs -I{} basename {} | sed 's/^profile_//'))
                    _describe 'profile' profiles
                    ;;
            esac
        fi
    }
    compdef _claude_profile_zsh claude-profile
fi
