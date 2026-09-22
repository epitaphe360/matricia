# pixel-perfect

A visual QA skill for [Claude Code](https://claude.ai/code) that compares your live UI against a Figma design and reports every defect — colors, spacing, typography, alignment, missing elements.

Works with **web pages**, **iOS Simulator**, and **Android Emulator**.

---

## Requirements

### All targets
- [Claude Code](https://claude.ai/code) CLI installed

### Web pages
- A browser MCP server connected to Claude Code (e.g. [Playwright MCP](https://github.com/microsoft/playwright-mcp))

```bash
npx @playwright/mcp@latest
```

Add it to Claude Code:
```bash
claude mcp add playwright -- npx @playwright/mcp@latest
```

### iOS Simulator
- Xcode installed with command-line tools
- iOS Simulator running with your app open at the target screen

```bash
xcode-select --install
```

### Android Emulator
- Android SDK platform-tools installed (`adb` in PATH)
- Emulator running with your app open at the target screen

```bash
brew install android-platform-tools
```

---

## Installation

Copy the skill into your Claude Code skills directory:

```bash
cp -r . ~/.claude/skills/pixel-perfect
```

Or clone directly:

```bash
git clone https://github.com/Huc91/pixel-perfect-skill ~/.claude/skills/pixel-perfect
```

---

## Usage

In any Claude Code session, run:

```
/pixel-perfect <figma-url-or-image> <target>
```

### Examples

**Web page:**
```
/pixel-perfect https://figma.com/design/abc123/MyApp?node-id=1:2 http://localhost:3000/dashboard
```

**iOS Simulator** (navigate to the screen first, then run):
```
/pixel-perfect https://figma.com/design/abc123/MyApp?node-id=1:2 ios-simulator
```

**Android Emulator:**
```
/pixel-perfect https://figma.com/design/abc123/MyApp?node-id=1:2 android-emulator
```

**Local reference image instead of Figma:**
```
/pixel-perfect /path/to/design.png http://localhost:3000
```

---

## What it checks

- Layout & structure
- Spacing (padding, margin, gap)
- Typography (font family, size, weight, color, alignment)
- Colors (backgrounds, text, borders, icons, shadows)
- Borders & border radius
- Icons & images
- Components (buttons, inputs, cards, badges, nav)
- Missing or extra elements

---

## Output

A structured report printed in the conversation:

```
## Visual QA Report
### Overall verdict: PASS / NEEDS WORK / FAIL

#### CRITICAL
#### MAJOR
#### MINOR
### What matches
```

No files are written — the report lives in the conversation and any temporary screenshots are deleted immediately after comparison.
