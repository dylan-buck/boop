# Boop Shell Integration for Bash
# This file is sourced by ~/.bashrc to enable CLI monitoring

# Only activate if Boop socket exists (app is running)
if [[ -S "$HOME/.boop/sock" ]]; then

    # Generate a unique session ID
    _boop_uuid() {
        if command -v uuidgen &>/dev/null; then
            uuidgen | tr '[:upper:]' '[:lower:]'
        else
            # Fallback: use /dev/urandom
            head -c 16 /dev/urandom | xxd -p
        fi
    }

    # Get project name from git or directory
    _boop_project_name() {
        if git rev-parse --show-toplevel &>/dev/null 2>&1; then
            basename "$(git rev-parse --show-toplevel)"
        else
            basename "$PWD"
        fi
    }

    # Wrapper for claude command
    claude() {
        local session_id="$(_boop_uuid)"
        local project_name="$(_boop_project_name)"
        local boop_pty="$HOME/.boop/bin/boop-pty"

        if [[ -x "$boop_pty" ]]; then
            # Use PTY wrapper for output monitoring
            BOOP_PROJECT="$project_name" "$boop_pty" "$session_id" claude "$@"
        else
            # Fallback: run directly without monitoring
            command claude "$@"
        fi
    }

    # Wrapper for codex command
    codex() {
        local session_id="$(_boop_uuid)"
        local project_name="$(_boop_project_name)"
        local boop_pty="$HOME/.boop/bin/boop-pty"

        if [[ -x "$boop_pty" ]]; then
            # Use PTY wrapper for output monitoring
            BOOP_PROJECT="$project_name" "$boop_pty" "$session_id" codex "$@"
        else
            # Fallback: run directly without monitoring
            command codex "$@"
        fi
    }

    # Export functions for subshells
    export -f claude
    export -f codex
    export -f _boop_uuid
    export -f _boop_project_name

fi
