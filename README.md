# 📸 agent-screenshot

> Screen capture + AI vision analysis for agents.

A **tool** for [StratusOS](https://stratuslabs.io) — the AI operating system for Mac.

---

## What it does

Captures screen regions, windows, or full screens and optionally pipes them through a vision model for analysis. Perfect for visual QA, UI monitoring, and screenshot-driven workflows. Uses native macOS screen capture — no external dependencies.

## Installation

```bash
# From StratusOS Marketplace (recommended)
# Open StratusOS → Marketplace → Tools → agent-screenshot → Install

# Or manual:
git clone https://github.com/stratuslabs/tool-agent-screenshot.git ~/.stratusos/tools/agent-screenshot
```

## Usage

```bash
# Capture full screen
agent-screenshot --output screen.png

# Capture a specific window
agent-screenshot --window "Safari" --output safari.png

# Capture a region
agent-screenshot --region 0,0,800,600 --output region.png

# Capture and analyze with vision model
agent-screenshot --window "Safari" --analyze "Is there a login form visible?"
```

## Requirements

- StratusOS v0.2.0+
- macOS 15+ (Apple Silicon)
- Screen Recording permission (prompted on first use)

---

<p align="center">
  <br>
  Built for <a href="https://stratuslabs.io"><strong>StratusOS</strong></a> — your AI operating system.
  <br>
  <a href="https://github.com/stratuslabs">GitHub</a> · <a href="https://discord.gg/stratuslabs">Discord</a>
  <br>
  <br>
  <sub>Made by <a href="https://github.com/stratuslabs">Stratus Labs</a></sub>
</p>
