# Boop - Product Requirements Document

## Overview

**Boop** is a lightweight macOS menu bar utility that sends push notifications to your iPhone when AI coding assistants (Claude Code CLI, Codex CLI) complete tasks or need approval.

### Problem Statement

Developers using AI coding CLIs often context-switch while waiting for long-running tasks. They check their phones, get distracted, and miss when the AI finishes or needs input—breaking flow and wasting time.

### Solution

A "set and forget" background utility that monitors AI CLI sessions and pings your phone at the two moments that matter:
1. **Approval needed** - The AI is blocked waiting for permission
2. **Task completed** - The AI finished and returned to idle

### Target User

Developers who:
- Use Claude Code CLI and/or Codex CLI regularly
- Run sessions that take 2+ minutes
- Want to multitask without babysitting the terminal
- Use an iPhone

---

## Product Principles

1. **Zero friction after setup** - Works invisibly once installed
2. **Minimal surface area** - Only shows what matters
3. **Privacy-first** - No accounts, no cloud, no tracking
4. **Respectful** - Won't spam; honors system DND

---

## User Experience

### Installation & Onboarding

#### Step 1: Install App
```bash
brew install --cask boop
# or download DMG from GitHub releases
```

#### Step 2: First Launch
App opens onboarding flow:

```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│                      Welcome to Boop                   │
│                                                            │
│       Get notified when Claude or Codex needs you          │
│                                                            │
│                        [Get Started]                       │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

#### Step 3: Phone Setup
```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│                    Connect Your iPhone                     │
│                                                            │
│         1. Install "ntfy" from the App Store               │
│            [Open App Store]                                │
│                                                            │
│         2. Scan this QR code in the ntfy app               │
│                                                            │
│                    ┌──────────────┐                        │
│                    │  █▀▀▀▀▀▀▀█   │                        │
│                    │  █ QR    █   │                        │
│                    │  █ CODE  █   │                        │
│                    │  █▄▄▄▄▄▄▄█   │                        │
│                    └──────────────┘                        │
│                                                            │
│              Topic: boop-a1b2c3d4e5f6                  │
│                                                            │
│                    [Send Test Notification]                │
│                                                            │
│                         [Continue]                         │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

#### Step 4: Shell Integration
```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│                   Enable CLI Monitoring                    │
│                                                            │
│    Boop needs to add a hook to your shell to detect    │
│    when Claude and Codex need your attention.              │
│                                                            │
│    This adds one line to ~/.zshrc:                         │
│    ┌────────────────────────────────────────────────────┐  │
│    │  source "$HOME/.boop/hook.zsh"                 │  │
│    └────────────────────────────────────────────────────┘  │
│                                                            │
│    [View Full Changes]    [Install Automatically]          │
│                                                            │
│    ────────────────────────────────────────────────────    │
│    ⚠️  Restart your terminal after installation            │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

#### Step 5: Done
```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│                        You're all set!                     │
│                                                            │
│              Boop is running in your menu bar          │
│                                                            │
│                           [●]                              │
│                            ↑                               │
│                     Look for this icon                     │
│                                                            │
│    ────────────────────────────────────────────────────    │
│                                                            │
│    Next steps:                                             │
│    • Open a new terminal window                            │
│    • Run `claude` or `codex` as usual                      │
│    • Walk away - we'll ping you when it's ready            │
│                                                            │
│                     [Close & Start Using]                  │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

### Menu Bar

#### Icon States

| State | Icon | Meaning |
|-------|------|---------|
| Connected, idle | `●` (green) | Phone connected, no active sessions |
| Connected, working | `●` (blue) | Sessions running, no action needed |
| Connected, attention | `●` (orange) | Approval needed or task completed |
| Disconnected | `○` (gray outline) | Phone not connected or error |
| Paused | `⏸` (gray) | Notifications paused |

#### Dropdown Menu

**Active sessions:**
```
┌─────────────────────────────────────────────┐
│ Boop                              ⏸  ⚙️ │
├─────────────────────────────────────────────┤
│                                             │
│  🟡 my-api-project                          │
│     Claude · Waiting for approval           │
│                                             │
│  🟢 frontend-app                            │
│     Claude · Working · 4m                   │
│                                             │
│  ✓  backend-service                         │
│     Codex · Completed · 2m ago              │
│                                             │
├─────────────────────────────────────────────┤
│  📱 Connected                               │
├─────────────────────────────────────────────┤
│  Quit Boop                              │
└─────────────────────────────────────────────┘
```

**No active sessions:**
```
┌─────────────────────────────────────────────┐
│ Boop                              ⏸  ⚙️ │
├─────────────────────────────────────────────┤
│                                             │
│  No active sessions                         │
│                                             │
├─────────────────────────────────────────────┤
│  📱 Connected                               │
├─────────────────────────────────────────────┤
│  Quit Boop                              │
└─────────────────────────────────────────────┘
```

**Phone not set up:**
```
┌─────────────────────────────────────────────┐
│ Boop                              ⏸  ⚙️ │
├─────────────────────────────────────────────┤
│                                             │
│  No active sessions                         │
│                                             │
├─────────────────────────────────────────────┤
│  📱 Set up phone notifications →            │
├─────────────────────────────────────────────┤
│  Quit Boop                              │
└─────────────────────────────────────────────┘
```

#### Session States

| State | Icon | Shows |
|-------|------|-------|
| Working | 🟢 | `{project} · {tool} · Working · {duration}` |
| Waiting for approval | 🟡 | `{project} · {tool} · Waiting for approval` |
| Completed | ✓ | `{project} · {tool} · Completed · {time} ago` |
| Error | 🔴 | `{project} · {tool} · Error` |

**Project name derivation (priority order):**
1. Claude/Codex session name if set
2. Git repo name if in a git directory
3. Parent folder name
4. `~` if home directory

---

### Settings Window

Opened via ⚙️ button in dropdown.

```
┌───────────────────────────────────────────────────────────────┐
│ Boop Settings                                         ✕   │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  PHONE NOTIFICATIONS                                          │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                                                         │  │
│  │  Status: ✅ Connected                                   │  │
│  │  Topic: boop-a1b2c3d4e5f6                          │  │
│  │                                                         │  │
│  │  [Show QR Code]  [Send Test]  [Regenerate Topic]       │  │
│  │                                                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  NOTIFY WHEN                                                  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  [✓] Approval needed              Priority: [Urgent ▼]  │  │
│  │  [✓] Task completed               Priority: [Default ▼] │  │
│  │  [✓] Errors                       Priority: [High ▼]    │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  MONITORED TOOLS                                              │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  [✓] Claude Code CLI                                    │  │
│  │  [✓] Codex CLI                                          │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  SHELL INTEGRATION                                            │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Status: ✅ Installed                                   │  │
│  │  Location: ~/.zshrc                                     │  │
│  │                                                         │  │
│  │  [Reinstall Hook]  [Uninstall Hook]                     │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  GENERAL                                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  [✓] Launch at login                                    │  │
│  │  [✓] Respect Do Not Disturb                             │  │
│  │                                                         │  │
│  │  Quiet hours: [Off ▼]                                   │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  ───────────────────────────────────────────────────────────  │
│  Boop v1.0.0                                              │
│  [GitHub]  [Report Issue]  [Check for Updates]                │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

---

### Notifications

#### Approval Needed
```
┌─────────────────────────────────────────┐
│ 🟡 Boop                             │
├─────────────────────────────────────────┤
│ my-api-project                          │
│ Claude is waiting for approval          │
└─────────────────────────────────────────┘
```
- Priority: Urgent (breaks through DND on phone if configured in ntfy)

#### Task Completed
```
┌─────────────────────────────────────────┐
│ ✅ Boop                             │
├─────────────────────────────────────────┤
│ my-api-project                          │
│ Claude finished                         │
└─────────────────────────────────────────┘
```
- Priority: Default

#### Error
```
┌─────────────────────────────────────────┐
│ 🔴 Boop                             │
├─────────────────────────────────────────┤
│ my-api-project                          │
│ Claude encountered an error             │
└─────────────────────────────────────────┘
```
- Priority: High

---

## Technical Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              macOS                                      │
│                                                                         │
│  ┌──────────────────┐      ┌──────────────────────────────────────────┐│
│  │   Terminal.app   │      │            Boop.app                  ││
│  │   Ghostty        │      │  ┌──────────────────────────────────┐    ││
│  │   iTerm2         │      │  │         Menu Bar UI              │    ││
│  │   etc.           │      │  │         (SwiftUI)                │    ││
│  │                  │      │  └──────────────────────────────────┘    ││
│  │  ┌────────────┐  │      │                  │                       ││
│  │  │   zsh      │  │      │                  ▼                       ││
│  │  │            │  │      │  ┌──────────────────────────────────┐    ││
│  │  │ source     │  │      │  │       Session Manager            │    ││
│  │  │ hook.zsh   │──┼──────┼─▶│  • Track active sessions         │    ││
│  │  │            │  │ IPC  │  │  • State machine per session     │    ││
│  │  │ claude ... │  │(Unix │  │  • Pattern detection             │    ││
│  │  │ codex ...  │  │Socket)│  └──────────────────────────────────┘    ││
│  │  └────────────┘  │      │                  │                       ││
│  └──────────────────┘      │                  ▼                       ││
│                            │  ┌──────────────────────────────────┐    ││
│                            │  │     Notification Dispatcher      │    ││
│                            │  │  • Debouncing                    │    ││
│                            │  │  • DND awareness                 │    ││
│                            │  │  • ntfy.sh client                │    ││
│                            │  └──────────────────────────────────┘    ││
│                            └──────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
                                            │
                                            ▼ HTTPS POST
                                    ┌───────────────┐
                                    │   ntfy.sh     │
                                    │   (public)    │
                                    └───────────────┘
                                            │
                                            ▼ Push
                                    ┌───────────────┐
                                    │    iPhone     │
                                    │   ntfy app    │
                                    └───────────────┘
```

### Components

#### 1. Shell Hook (`~/.boop/hook.zsh`)

Wraps `claude` and `codex` commands transparently:

```zsh
# ~/.boop/hook.zsh

# Only activate if Boop is running
if [[ -S "$HOME/.boop/sock" ]]; then
    
    claude() {
        # Determine session/project name
        local project_name="${PWD##*/}"
        if git rev-parse --show-toplevel &>/dev/null; then
            project_name="$(basename "$(git rev-parse --show-toplevel)")"
        fi
        
        # Generate unique session ID
        local session_id="$(uuidgen)"
        
        # Notify Boop: session starting
        echo "START|$session_id|claude|$project_name|$$" | nc -U "$HOME/.boop/sock" &>/dev/null
        
        # Run actual claude with PTY wrapper
        "$HOME/.boop/bin/boop-pty" "$session_id" claude "$@"
        local exit_code=$?
        
        # Notify Boop: session ended
        echo "END|$session_id|$exit_code" | nc -U "$HOME/.boop/sock" &>/dev/null
        
        return $exit_code
    }
    
    codex() {
        # Same pattern as above
        # ...
    }
fi
```

#### 2. PTY Wrapper (`boop-pty`)

Rust binary that:
- Spawns the real CLI in a pseudo-terminal
- Passes through all I/O transparently
- Pattern-matches output for state changes
- Reports state changes to main app via Unix socket

```
Session States:
  STARTING → WORKING → AWAITING_APPROVAL → WORKING → ... → COMPLETED
                 ↓                              ↓
               ERROR                          ERROR
```

#### 3. Session Manager (Swift)

- Listens on Unix socket for session events
- Maintains state machine for each active session
- Triggers notifications on state transitions
- Cleans up stale sessions (timeout after 24h)

#### 4. Notification Dispatcher (Swift)

- Receives notification requests from Session Manager
- Applies debouncing (no duplicate notifications within 30s for same session)
- Checks system DND status via `NSDoNotDisturbMode`
- Checks quiet hours setting
- Sends to ntfy.sh via HTTP POST

### Pattern Detection

Patterns to detect in CLI output (will require refinement through testing):

**Claude Code CLI - Approval Needed:**
```
- "Do you want to proceed?"
- "Allow this action?"
- "Press Enter to continue"
- "[Y/n]"
- "Waiting for approval"
- "requires your permission"
```

**Claude Code CLI - Completed:**
```
- Returns to prompt ("❯" or similar)
- "Task completed"
- Exit code 0 with no pending prompt
```

**Codex CLI - Approval Needed:**
```
- "approve"
- "[y/N]"
- "confirm"
```

**Codex CLI - Completed:**
```
- Returns to idle state
- Exit code 0
```

*Note: Exact patterns TBD based on testing. Should be configurable/updatable.*

### Data Storage

Location: `~/.boop/`

```
~/.boop/
├── config.json          # User preferences
├── hook.zsh             # Shell hook script
├── sock                  # Unix socket for IPC
├── bin/
│   └── boop-pty     # PTY wrapper binary
└── logs/
    └── boop.log     # Debug logging (optional)
```

**config.json:**
```json
{
  "version": 1,
  "ntfy": {
    "topic": "boop-a1b2c3d4e5f6",
    "server": "https://ntfy.sh"
  },
  "notifications": {
    "approval": { "enabled": true, "priority": "urgent" },
    "completed": { "enabled": true, "priority": "default" },
    "error": { "enabled": true, "priority": "high" }
  },
  "tools": {
    "claude": true,
    "codex": true
  },
  "quietHours": {
    "enabled": false,
    "start": "22:00",
    "end": "08:00"
  },
  "respectDND": true,
  "launchAtLogin": true
}
```

### Security Considerations

1. **ntfy topic is secret** - Generated with cryptographically random string (24 chars). Anyone with the topic can send notifications, so it's treated like a token.

2. **No credentials stored** - We don't need Claude/Codex auth; we just watch terminal output.

3. **Local IPC only** - Unix socket with restrictive permissions (0600).

4. **No network except ntfy** - Only outbound HTTPS to ntfy.sh.

5. **No telemetry** - Zero data collection.

---

## Notification Service: ntfy.sh

### Why ntfy.sh

- **Free tier is sufficient** - 60 message burst, refills at 1/5s (~720/hour)
- **No account required** - Just pick a topic name
- **iOS app available** - Native push notifications
- **Open source** - Can self-host if needed
- **Simple API** - Single HTTP POST to send

### Free Tier Limits

| Limit | Value | Boop Impact |
|-------|-------|-----------------|
| Burst | 60 messages | More than enough |
| Refill | 1 message per 5 seconds | ~720/hour possible |
| Daily | Effectively unlimited | ✅ |
| Message cache | 12 hours | Fine |
| Attachments | 15 MB | Not used |

**Typical Boop usage:**
- ~10-20 AI sessions/day (heavy user)
- ~2-3 notifications per session
- **Max ~60 notifications/day** = well within limits

### Self-Hosting (Optional)

For enterprise users or privacy-conscious users, ntfy can be self-hosted. Documentation: https://docs.ntfy.sh/install/

---

## Technical Requirements

### Platform
- macOS 14+ (Sonoma)
- Apple Silicon + Intel

### Dependencies
- Swift 5.9+
- SwiftUI
- Rust (for PTY wrapper)
- ntfy.sh (external service)

### Build & Distribution
- Swift Package Manager for app
- Cargo for Rust component
- Signed + notarized for Gatekeeper
- Homebrew cask for installation
- GitHub Releases for direct download
- Sparkle for auto-updates

---

## Milestones

### v0.1 - Proof of Concept (1 week)
- [ ] Basic menu bar app (SwiftUI)
- [ ] Shell hook that detects claude/codex invocation
- [ ] Simple pattern matching for "awaiting" state
- [ ] ntfy.sh notification sending
- [ ] Manual testing with real Claude Code sessions

### v0.2 - Core Features (1 week)
- [ ] PTY wrapper in Rust
- [ ] Full state machine (working/awaiting/completed)
- [ ] Session tracking (multiple terminals)
- [ ] Settings UI
- [ ] QR code onboarding

### v0.3 - Polish (1 week)
- [ ] DND awareness
- [ ] Quiet hours
- [ ] Debouncing/batching
- [ ] Launch at login
- [ ] Shell hook installer UI
- [ ] Error handling & edge cases

### v1.0 - Release (3 days)
- [ ] Code signing & notarization
- [ ] Homebrew cask formula
- [ ] Documentation
- [ ] Landing page
- [ ] GitHub release

---

## Future Ideas (Post v1)

- **Codex.app support** - Monitor native macOS app via Accessibility API
- **Cursor/Windsurf support** - Detect other AI coding tools
- **Local Mac notifications** - In addition to phone push
- **Watch app** - Quick glance at sessions from wrist
- **Custom notification sounds**
- **Pushover support** - Alternative to ntfy.sh
- **Self-hosted ntfy** - Enterprise/privacy documentation
- **Linux support** - Menu bar via system tray
- **Session history** - Log of past sessions
- **Time tracking** - How long AI spent on tasks
- **Multiple Macs** - Unified session view across machines

---

## Open Questions

1. **Pattern accuracy** - Will require iterative refinement through real-world testing with Claude Code and Codex CLI sessions. May need to ship with a pattern update mechanism.

---

## Success Metrics

1. **Setup completion rate** - % of users who complete onboarding
2. **Daily active users** - Users who receive at least one notification/day
3. **Notification accuracy** - False positive/negative rate (via user feedback)
4. **GitHub stars** - Community adoption signal

---

*PRD Version: 1.0*  
*Last Updated: February 2025*
