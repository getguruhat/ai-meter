# Contributing to AI Meter

Thanks for helping. AI Meter is a small, free app that shows how much of your Claude Code or Codex usage is left in the menu bar. Bug reports, ideas and pull requests are all welcome.

## Reporting a problem

Open an issue with the bug report form. Include your AI Meter version, your macOS version, and whether it's Claude Code or Codex. Never paste tokens or the contents of credential files.

The Windows version lives in [getguruhat/ai-meter-windows](https://github.com/getguruhat/ai-meter-windows).

## Building it

```
swift build -c release
./build-app.sh    # makes AI Meter.app
```

See the README for details. AI Meter reads the Claude Code sign-in in the Keychain (`Claude Code-credentials`) or `~/.claude/.credentials.json`, and the Codex sign-in in `~/.codex/auth.json`, so sign in with `claude` or `codex` in a terminal once before testing.

## Pull requests

- Keep a pull request to one change, and say how you tested it.
- Match the style of the code around it.
- AI Meter sends a token only to the provider it belongs to (Anthropic or OpenAI) and has no analytics. Changes that add tracking, accounts or other servers won't be merged.
- By contributing, you agree that your work is released under this repo's MIT license.

## Questions

Open an issue, or email hello@guruhat.com.
