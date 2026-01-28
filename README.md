# Skills

Agent Skills for AI coding assistants. These skills follow the [Agent Skills Standard](https://github.com/anthropics/skills) and work with Claude Code, Cursor, Gemini Code Assist, GitHub Copilot, and other compatible tools.

## Available Skills

- [simulator-screenshot](simulator-screenshot/SKILL.md): Capture screenshots from iOS Simulator or Android Emulator using the bundled simulator-screenshot.sh script. Use when asked to take simulator/emulator screenshots, list available devices, select a specific simulator or emulator by ID/name, or return JSON output for automation.

## Installation

Via `skills` CLI:

```bash
npx skills add https://github.com/KrzysztofMoch/skills --skill simulator-screenshot
```

Or manually:
1. Clone this repository or download the ZIP.
2. Copy the `simulator-screenshot` folder into your agent's skills directory.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.