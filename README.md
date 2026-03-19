# 📸 agent-screenshot

> Screen capture + AI vision analysis for agents.

A **tool** for [StratusOS](https://stratuslabs.io) — the AI operating system for Mac.

---

## What it does

Captures screen regions, windows, or full screens and optionally pipes them through a vision model for analysis. Perfect for visual QA, UI monitoring, and screenshot-driven workflows. Uses **ScreenCaptureKit** (macOS 14+) for modern, performant screen capture — no external dependencies.

## Installation

```bash
# From StratusOS Marketplace (recommended)
# Open StratusOS → Marketplace → Tools → agent-screenshot → Install

# Or manual:
git clone https://github.com/stratuslabs/tool-agent-screenshot.git ~/.stratusos/tools/agent-screenshot
```

## Usage

### CLI Mode

```bash
# Capture full screen
agent-screenshot --output screen.png

# Capture a specific display (multi-monitor)
agent-screenshot --display 1 --output display2.png

# Capture a specific window
agent-screenshot --window "Safari" --output safari.png

# Capture a region
agent-screenshot --region 0,0,800,600 --output region.png

# Capture a region on a specific display
agent-screenshot --region 0,0,800,600 --display 1 --output region.png

# Capture and analyze with vision model (TODO)
agent-screenshot --window "Safari" --analyze "Is there a login form visible?"
```

### JSON Input Mode

```bash
# Full screen capture
echo '{"command":"capture","args":{"output":"/tmp/screen.png"}}' | agent-screenshot --json

# Capture a specific display
echo '{"command":"capture","args":{"display":1,"output":"/tmp/display2.png"}}' | agent-screenshot --json

# Window capture
echo '{"command":"capture","args":{"window":"Safari","output":"/tmp/safari.png"}}' | agent-screenshot --json

# Region capture
echo '{"command":"capture","args":{"region":{"x":0,"y":0,"w":800,"h":600},"output":"/tmp/region.png"}}' | agent-screenshot --json
```

All commands return JSON output:
```json
{
  "success": true,
  "path": "/tmp/screen.png",
  "width": 1920,
  "height": 1080,
  "format": "png"
}
```

## Requirements

- StratusOS v0.2.0+
- macOS 14+ (Sonoma or later)
- Apple Silicon or Intel
- Screen Recording permission (System Settings > Privacy & Security > Screen Recording)

## Building

```bash
./build.sh
```

Or manually:
```bash
swiftc -parse-as-library \
    src/main.swift \
    -framework ScreenCaptureKit \
    -framework CoreGraphics \
    -framework AppKit \
    -framework Foundation \
    -o agent-screenshot
```

---

<p align="center">
  <br>
  Built for <a href="https://stratuslabs.io"><strong>StratusOS</strong></a> — your AI operating system.
  <br>
  <a href="https://github.com/stratuslabs">GitHub</a> · <a href="https://discord.gg/PNJseAMbPn">Discord</a>
  <br>
  <br>
  <sub>Made by <a href="https://github.com/stratuslabs">Stratus Labs</a></sub>
</p>
