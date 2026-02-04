# Boop

**Get notified on your phone when Claude Code or Codex needs you.**

A lightweight macOS menu bar app that sends push notifications to your iPhone when AI coding assistants complete tasks or need approval.

---

## The Problem

You start a task in Claude Code, switch to Slack while waiting... and 20 minutes later realize Claude finished ages ago. Or worse, it's been blocked waiting for your approval.

## The Solution

Boop monitors your AI CLI sessions and pings your phone at the moments that matter:

- **Approval needed** - Claude is blocked waiting for permission
- **Task completed** - Claude finished and is ready for your next prompt

No more babysitting the terminal. Start a task, walk away, get notified.

---

## Quick Start

### 1. Install Boop on your Mac

```bash
# Download the latest release
# (Homebrew cask coming soon)
```

Or download the DMG from [GitHub Releases](https://github.com/dylan-buck/boop/releases).

### 2. Install ntfy on your iPhone

<a href="https://apps.apple.com/app/ntfy/id1625396347">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="50">
</a>

[ntfy](https://ntfy.sh) is a free, open-source notification service. No account required.

### 3. Connect your phone

1. **Launch Boop** - It appears in your menu bar
2. **Open the onboarding** - Click the Boop icon → Settings
3. **Scan the QR code** - Open ntfy app → tap **+** → "Scan QR code"
4. **Test it** - Click "Send Test Notification" in Boop

You should see a notification on your phone within seconds.

### 4. Add the shell integration

Boop needs to wrap your `claude` command to monitor sessions:

```bash
# Add this line to your ~/.zshrc (or ~/.bashrc)
source "$HOME/.boop/hook.zsh"
```

Then restart your terminal.

### 5. Use Claude as normal

```bash
claude "refactor the authentication module"
```

Walk away. Boop will notify you when Claude needs approval or finishes.

---

## How It Works

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Terminal   │────▶│    Boop     │────▶│   ntfy.sh   │────▶│   iPhone    │
│  (claude)   │     │  (menu bar) │     │   (free)    │     │  (ntfy app) │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

1. **Shell hook** wraps `claude`/`codex` commands
2. **PTY wrapper** monitors terminal output for state changes
3. **Boop** detects when Claude is waiting for approval or idle
4. **ntfy.sh** delivers push notifications to your phone

### What triggers notifications?

| Event | Trigger | Priority |
|-------|---------|----------|
| Approval needed | Claude shows `[Y/n]`, "waiting for approval", etc. | Urgent |
| Task completed | Claude shows the `>` prompt (idle for 30+ seconds) | Default |
| Error | Process exits with error | High |

---

## Features

- **Menu bar status** - See active sessions at a glance
- **Multiple sessions** - Track sessions across multiple terminal windows
- **Quiet hours** - Disable notifications during sleep hours
- **Do Not Disturb** - Respects macOS DND settings
- **Debouncing** - Won't spam you with duplicate notifications
- **Privacy-first** - No accounts, no cloud, no tracking

---

## Privacy & Security

- **No account required** - ntfy.sh works with anonymous "topics" (like private channels)
- **Random topic** - Boop generates a cryptographically random topic for you
- **No data collection** - Zero telemetry, zero tracking
- **Local only** - All processing happens on your Mac
- **Open source** - Audit the code yourself

Your ntfy topic is like a password - anyone with it can send you notifications. Keep it private.

---

## Configuration

Settings are stored in `~/.boop/config.json`:

```json
{
  "ntfy": {
    "topic": "boop-xxxxxxxxxxxxxxxx",
    "server": "https://ntfy.sh"
  },
  "notifications": {
    "approval": { "enabled": true, "priority": "urgent" },
    "completed": { "enabled": true, "priority": "default" },
    "error": { "enabled": true, "priority": "high" }
  },
  "quietHours": {
    "enabled": false,
    "start": "22:00",
    "end": "08:00"
  },
  "respectDND": true
}
```

### Self-hosted ntfy

For extra privacy, you can [self-host ntfy](https://docs.ntfy.sh/install/) and point Boop to your server:

```json
{
  "ntfy": {
    "server": "https://ntfy.your-domain.com"
  }
}
```

---

## Supported Tools

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude`)
- [Codex CLI](https://github.com/openai/codex) (`codex`)

More coming soon (Cursor, Windsurf, etc.)

---

## Requirements

- macOS 14+ (Sonoma)
- iPhone with [ntfy app](https://apps.apple.com/app/ntfy/id1625396347)
- Claude Code CLI or Codex CLI

---

## Building from Source

### Prerequisites

- Xcode 15+
- Rust toolchain (`rustup`)

### Build

```bash
# Clone the repo
git clone https://github.com/dylan-buck/boop.git
cd boop

# Build the Rust PTY wrapper
cd boop-pty
cargo build --release
cd ..

# Open in Xcode
open Boop/Boop.xcodeproj

# Build and run (Cmd+R)
```

---

## Troubleshooting

### Notifications not arriving?

1. **Check ntfy app** - Make sure you're subscribed to the correct topic
2. **Test notification** - Click "Send Test" in Boop settings
3. **Check phone settings** - Ensure ntfy has notification permissions
4. **Check quiet hours** - Make sure they're not active

### Shell hook not working?

1. **Source the hook** - Add `source "$HOME/.boop/hook.zsh"` to your shell config
2. **Restart terminal** - The hook only loads in new shells
3. **Check Boop is running** - The hook only activates when Boop is running

### Claude completing but no notification?

Notifications only trigger if Claude worked for **30+ seconds**. Quick tasks don't notify.

---

## Contributing

Contributions welcome! Please open an issue first to discuss what you'd like to change.

---

## License

MIT

---

## Acknowledgments

- [ntfy.sh](https://ntfy.sh) - Free, open-source push notifications
- Inspired by [CodexBar](https://github.com/steipete/CodexBar)
